// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/core/UserOperationLib.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {CABPaymaster} from "../src/paymasters/CABPaymaster.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {InvoiceManager} from "../src/core/InvoiceManager.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {IInvoiceManager} from "../src/interfaces/IInvoiceManager.sol";
import {UpgradeableOpenfortProxy} from "../src/proxy/UpgradeableOpenfortProxy.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IPaymasterVerifier} from "../src/interfaces/IPaymasterVerifier.sol";
import {UserOpSettlement} from "../src/settlement/UserOpSettlement.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";
import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";

contract CABPaymasterTest is Test {
    uint256 immutable BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 immutable OPTIMISM_CHAIN_ID = 11155420;
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
        console.log("mockERC20", address(mockERC20));
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
            sponsorTokens[i] = IPaymasterVerifier.SponsorToken({token: address(mockERC20), spender: rekt, amount: 500});
            encodedSponsorToken = bytes.concat(
                encodedSponsorToken,
                bytes20(sponsorTokens[i].token),
                bytes20(sponsorTokens[i].spender),
                bytes32(sponsorTokens[i].amount)
            );
        }
        return abi.encodePacked(uint8(len), encodedSponsorToken);
    }


    function encodeRepayToken(IInvoiceManager.RepayTokenInfo[] memory repayTokens) internal pure returns (bytes memory encodedRepayToken) {
        for (uint8 i = 0; i < repayTokens.length; i++) {
            encodedRepayToken = bytes.concat(
                encodedRepayToken,
                bytes20(address(repayTokens[i].vault)),
                bytes32(repayTokens[i].amount),
                bytes32(repayTokens[i].chainId)
            );
        }
        return abi.encodePacked(uint8(repayTokens.length), encodedRepayToken);
    }

    function getEncodedRepayTokens(uint8 len) internal returns (bytes memory encodedRepayToken) {
        IInvoiceManager.RepayTokenInfo[] memory repayTokens = new IInvoiceManager.RepayTokenInfo[](len);
        for (uint8 i = 0; i < len; i++) {
            repayTokens[i] =
                IInvoiceManager.RepayTokenInfo({vault: openfortVault, amount: 500, chainId: OPTIMISM_CHAIN_ID});
            encodedRepayToken = bytes.concat(
                encodedRepayToken,
                bytes20(address(repayTokens[i].vault)),
                bytes32(repayTokens[i].amount),
                bytes32(repayTokens[i].chainId)
            );
        }
        return abi.encodePacked(uint8(len), encodedRepayToken);
    }

    function testEncodeRepayToken() public {
        IInvoiceManager.RepayTokenInfo[] memory repayTokens = new IInvoiceManager.RepayTokenInfo[](1);
        repayTokens[0] = IInvoiceManager.RepayTokenInfo({vault: IVault(address(0x8e2048c85Eae2a4443408C284221B33e61906463)), amount: 500, chainId: OPTIMISM_CHAIN_ID});
        bytes memory encodedRepayToken = encodeRepayToken(repayTokens);
        assertEq(encodedRepayToken, hex"018e2048c85Eae2a4443408C284221B33e6190646300000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000aa37dc");
    }

    function testValidateUserOp() public {
        vm.chainId(BASE_SEPOLIA_CHAIN_ID);
        bytes memory sponsorTokensBytes = getEncodedSponsorTokens(1);
        bytes memory repayTokensBytes = getEncodedRepayTokens(1);

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
            repayTokensBytes,
            sponsorTokensBytes
        );

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: rekt,
            nonce: 31994562304018791559173496635392,
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
                keccak256(abi.encode(repayTokensBytes, sponsorTokensBytes)),
                bytes32(abi.encodePacked(preVerificationGas, postVerificationGas)),
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

        userOp.paymasterAndData = bytes.concat(userOp.paymasterAndData, signature);

        // DEMO paymasterAndData with sponsorToken address replaced by MockToken address to pass the approve in the paymaster
        // userOp.paymasterAndData =
        //    hex"F6e64504ed56ec2725CDd0b3C1b23626D66008A2000000000000000000000000000f4240000000000000000000000000000186a000000136ea9100000127a851018e2048c85Eae2a4443408C284221B33e6190646300000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000aa37dc01a0Cb889707d426A7A386870A03bc70d1b0697598Fb619E988fD324734be51b0475A67b6921D0301f00000000000000000000000000000000000000000000000000000000000001f4b6e46e8f25f10e368181d6957e4c4021d7d563dfde06cf9e12d8f1c31a88986c3755ef5dcfed29cda855f525c473d1310890389bd5232da23946ed27594796111c";

        vm.startPrank(address(entryPoint));
        (bytes memory context, uint256 validationData) =
            paymaster.validatePaymasterUserOp(userOp, userOpHash, type(uint256).max);

        // validate postOp
        // This is the event that we must track on dest chain and prove on source chain with Polymer proof system

        // Calculate the expected invoiceId
        bytes32 expectedInvoiceId =
            invoiceManager.getInvoiceId(rekt, address(paymaster), userOp.nonce, BASE_SEPOLIA_CHAIN_ID, repayTokensBytes);
        vm.expectEmit(true, true, true, true);
        emit IPaymasterVerifier.InvoiceCreated(expectedInvoiceId);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 1222, 42);
    }

    function testGetInvoiceId() public {
        address account = 0x5E3Ae8798eAdE56c3B4fe8F085DAd16D4912Ba83;
        address paymaster = 0xF6e64504ed56ec2725CDd0b3C1b23626D66008A2;
        uint256 nonce = 32005827482497451446878209048576;
        uint256 sponsorChainId = 84532;

        IInvoiceManager.RepayTokenInfo[] memory repayTokens = new IInvoiceManager.RepayTokenInfo[](1);
        repayTokens[0] = IInvoiceManager.RepayTokenInfo({
            vault: IVault(0x8e2048c85Eae2a4443408C284221B33e61906463),
            amount: 500,
            chainId: 11155420
        });

        bytes32 expectedInvoiceId = 0xccabf5a2f5630bf7e426047c30d25fd0afe4bff9651bc648b4174153a38e38d8;
        bytes32 computedInvoiceId =
            invoiceManager.getInvoiceId(account, paymaster, nonce, sponsorChainId, abi.encode(repayTokens));
        assertEq(computedInvoiceId, expectedInvoiceId, "Invoice ID computation mismatch");
    }
}
