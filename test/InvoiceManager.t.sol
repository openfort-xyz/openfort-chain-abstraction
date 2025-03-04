// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InvoiceManager} from "../contracts/core/InvoiceManager.sol";
import {IInvoiceManager} from "../contracts/interfaces/IInvoiceManager.sol";
import {IPaymasterVerifier} from "../contracts/interfaces/IPaymasterVerifier.sol";
import {IVault} from "../contracts/interfaces/IVault.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {MockERC20} from "../contracts/mocks/MockERC20.sol";
import {MockPaymasterVerifier} from "../contracts/mocks/MockPaymasterVerifier.sol";
import {UpgradeableOpenfortProxy} from "../contracts/proxy/UpgradeableOpenfortProxy.sol";
import {BaseVault} from "../contracts/vaults/BaseVault.sol";
import {VaultManager} from "../contracts/vaults/VaultManager.sol";
import {Test} from "forge-std/Test.sol";

contract InvoiceManagerTest is Test {
    InvoiceManager public invoiceManager;
    VaultManager public vaultManager;
    MockPaymasterVerifier public paymasterVerifier;
    MockPaymasterVerifier public fallbackVerifier;
    BaseVault public vault;
    MockERC20 public mockERC20;

    address public owner;
    address public smartAccount;
    address public paymaster;

    function setUp() public {
        owner = makeAddr("owner");
        smartAccount = makeAddr("smartAccount");
        paymaster = makeAddr("paymaster");

        // Setup mock verifiers
        paymasterVerifier = new MockPaymasterVerifier(true);
        fallbackVerifier = new MockPaymasterVerifier(true);

        // Deploy and initialize InvoiceManager with proxy
        invoiceManager = InvoiceManager(payable(new UpgradeableOpenfortProxy(address(new InvoiceManager()), "")));

        // Deploy and initialize VaultManager with proxy
        vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new VaultManager()),
                    abi.encodeWithSelector(VaultManager.initialize.selector, owner, IInvoiceManager(address(invoiceManager)), 42)
                )
            )
        );

        // Deploy mock ERC20 and vault
        mockERC20 = new MockERC20();
        vault = BaseVault(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new BaseVault()),
                    abi.encodeWithSelector(BaseVault.initialize.selector, IVaultManager(address(vaultManager)), mockERC20)
                )
            )
        );

        // Initialize InvoiceManager
        vm.startPrank(owner);
        invoiceManager.initialize(owner, IVaultManager(address(vaultManager)), IPaymasterVerifier(address(fallbackVerifier)));

        // Register vault with VaultManager
        vaultManager.addVault(vault);

        vm.stopPrank();

        // Verify setup
        assertEq(address(vaultManager.invoiceManager()), address(invoiceManager));
        assertEq(address(invoiceManager.vaultManager()), address(vaultManager));
    }

    function test_RegisterPaymaster() public {
        vm.startPrank(smartAccount);

        uint256 expiry = block.timestamp + 1 days;
        invoiceManager.registerPaymaster(paymaster, IPaymasterVerifier(address(paymasterVerifier)), expiry);

        IInvoiceManager.CABPaymaster memory registeredPaymaster = invoiceManager.getCABPaymaster(smartAccount);
        assertEq(registeredPaymaster.paymaster, paymaster);
        assertEq(address(registeredPaymaster.paymasterVerifier), address(paymasterVerifier));
        assertEq(registeredPaymaster.expiry, expiry);

        vm.stopPrank();
    }

    function test_RegisterPaymaster_RevertIfAlreadyRegistered() public {
        vm.startPrank(smartAccount);

        uint256 expiry = block.timestamp + 1 days;
        invoiceManager.registerPaymaster(paymaster, IPaymasterVerifier(address(paymasterVerifier)), expiry);

        vm.expectRevert("InvoiceManager: paymaster already registered");
        invoiceManager.registerPaymaster(paymaster, IPaymasterVerifier(address(paymasterVerifier)), expiry);

        vm.stopPrank();
    }

    function test_RevokePaymaster() public {
        vm.startPrank(smartAccount);

        uint256 expiry = block.timestamp + 1 days;
        invoiceManager.registerPaymaster(paymaster, IPaymasterVerifier(address(paymasterVerifier)), expiry);

        // Warp time to after expiry
        vm.warp(expiry + 1);

        invoiceManager.revokePaymaster();

        IInvoiceManager.CABPaymaster memory registeredPaymaster = invoiceManager.getCABPaymaster(smartAccount);
        assertEq(registeredPaymaster.paymaster, address(0));

        vm.stopPrank();
    }

    function test_CreateInvoice() public {
        vm.startPrank(smartAccount);

        uint256 expiry = block.timestamp + 1 days;
        invoiceManager.registerPaymaster(paymaster, IPaymasterVerifier(address(paymasterVerifier)), expiry);

        vm.stopPrank();

        uint256 nonce = 1;
        bytes32 invoiceId = keccak256(abi.encodePacked("test_invoice"));

        vm.prank(paymaster);
        invoiceManager.createInvoice(nonce, smartAccount, invoiceId);

        IInvoiceManager.Invoice memory invoice = invoiceManager.getInvoice(invoiceId);
        assertEq(invoice.account, smartAccount);
        assertEq(invoice.nonce, nonce);
        assertEq(invoice.paymaster, paymaster);
        assertEq(invoice.sponsorChainId, block.chainid);
    }

    function test_Repay() public {
        // Setup repay token info with the real vault
        IVault[] memory vaults = new IVault[](1);
        vaults[0] = vault;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        IInvoiceManager.RepayTokenInfo[] memory repayTokenInfos = new IInvoiceManager.RepayTokenInfo[](1);
        repayTokenInfos[0] = IInvoiceManager.RepayTokenInfo({vault: vault, chainId: block.chainid, amount: amounts[0]});

        // Register paymaster
        vm.prank(smartAccount);
        invoiceManager.registerPaymaster(paymaster, IPaymasterVerifier(address(paymasterVerifier)), block.timestamp + 1 days);

        // Create invoice
        uint256 nonce = 1;
        bytes32 invoiceId =
            invoiceManager.getInvoiceId(smartAccount, paymaster, nonce, block.chainid, abi.encode(repayTokenInfos));

        vm.prank(paymaster);
        invoiceManager.createInvoice(nonce, smartAccount, invoiceId);

        // Prepare repayment
        IInvoiceManager.InvoiceWithRepayTokens memory invoiceWithRepay = IInvoiceManager.InvoiceWithRepayTokens({
            account: smartAccount,
            paymaster: paymaster,
            nonce: nonce,
            sponsorChainId: block.chainid,
            repayTokenInfos: repayTokenInfos
        });

        // Fund the vault and deposit for smart account
        mockERC20.mint(smartAccount, amounts[0]);

        vm.startPrank(smartAccount);
        mockERC20.approve(address(vaultManager), amounts[0]);
        vaultManager.deposit(mockERC20, vault, amounts[0], false);
        vm.stopPrank();

        // Repay
        invoiceManager.repay(invoiceId, invoiceWithRepay, "");

        assertTrue(invoiceManager.isInvoiceRepaid(invoiceId));
    }
}
