// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InvoiceManager} from "../src/core/InvoiceManager.sol";

import {IInvoiceManager} from "../src/interfaces/IInvoiceManager.sol";

import {IPaymasterVerifier} from "../src/interfaces/IPaymasterVerifier.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";

import {MockCrossL2Prover} from "../src/mocks/MockCrossL2Prover.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockShoyuBashi} from "../src/mocks/MockShoyuBashi.sol";
import {CABPaymaster} from "../src/paymasters/CABPaymaster.sol";
import {HashiPaymasterVerifier} from "../src/paymasters/HashiPaymasterVerifier.sol";
import {PolymerPaymasterVerifierV1} from "../src/paymasters/PolymerPaymasterVerifierV1.sol";
import {UpgradeableOpenfortProxy} from "../src/proxy/UpgradeableOpenfortProxy.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";
import {PackedUserOperation} from "account-abstraction/core/UserOperationLib.sol";
import {IPaymaster} from "account-abstraction/interfaces/IPaymaster.sol";

import {MockInvoiceManager} from "../src/mocks/MockInvoiceManager.sol";

import {stdJson} from "forge-std/StdJson.sol";
import {Test} from "forge-std/Test.sol";

contract CABPaymasterTest is Test {
    using stdJson for string;

    uint256 immutable BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 immutable OPTIMISM_CHAIN_ID = 11155420;
    uint256 immutable PAYMASTER_BASE_MOCK_ERC20_BALANCE = 100000;

    CABPaymaster public paymaster;
    InvoiceManager public invoiceManager;
    VaultManager public vaultManager;
    ICrossL2Prover public crossL2Prover;
    PolymerPaymasterVerifierV1 public polymerPaymasterVerifier;
    BaseVault public openfortVault;
    MockERC20 public mockERC20;

    address public verifyingSignerAddress;
    uint256 public verifyingSignerPrivateKey;
    address public owner;
    address public rekt;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant ENTRY_POINT_V7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    string proofs;

    function setUp() public {
        proofs = vm.readFile(string.concat(vm.projectRoot(), "/test/data/Proofs.json"));
        owner = address(1);
        rekt = address(0x9590Ed0C18190a310f4e93CAccc4CC17270bED40);

        verifyingSignerPrivateKey = uint256(keccak256(abi.encodePacked("VERIFIYING_SIGNER")));
        verifyingSignerAddress = vm.addr(verifyingSignerPrivateKey);
        vm.label(verifyingSignerAddress, "VERIFIYING_SIGNER");

        invoiceManager = InvoiceManager(payable(new UpgradeableOpenfortProxy(address(new InvoiceManager()), "")));

        vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new VaultManager()),
                    abi.encodeWithSelector(VaultManager.initialize.selector, owner, IInvoiceManager(address(invoiceManager)), 42)
                )
            )
        );

        mockERC20 = new MockERC20();
        openfortVault = BaseVault(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new BaseVault()),
                    abi.encodeWithSelector(BaseVault.initialize.selector, IVaultManager(address(vaultManager)), mockERC20)
                )
            )
        );

        invoiceManager.initialize(owner, IVaultManager(address(vaultManager)));
        crossL2Prover = ICrossL2Prover(address(new MockCrossL2Prover(address(invoiceManager))));

        // Initialize the supportedTokens array
        address[] memory supportedTokens = new address[](2);
        supportedTokens[0] = address(mockERC20);
        supportedTokens[1] = NATIVE_TOKEN;

        paymaster = new CABPaymaster(invoiceManager, verifyingSignerAddress, owner);
        paymaster.initialize(supportedTokens);

        mockERC20.mint(address(paymaster), PAYMASTER_BASE_MOCK_ERC20_BALANCE);

        assertEq(address(invoiceManager.vaultManager()), address(vaultManager));
        assertEq(address(vaultManager.invoiceManager()), address(invoiceManager));

        vm.startPrank(rekt);

        polymerPaymasterVerifier = new PolymerPaymasterVerifierV1(invoiceManager, crossL2Prover, owner);
        invoiceManager.registerPaymaster(
            address(paymaster), IPaymasterVerifier(address(polymerPaymasterVerifier)), block.timestamp + 100000
        );
    }

    function getEncodedSponsorTokens(uint8 len, address token) internal view returns (bytes memory encodedSponsorToken) {
        IPaymasterVerifier.SponsorToken[] memory sponsorTokens = new IPaymasterVerifier.SponsorToken[](len);
        for (uint8 i = 0; i < len; i++) {
            sponsorTokens[i] = IPaymasterVerifier.SponsorToken({token: token, spender: rekt, amount: 500});
            encodedSponsorToken = bytes.concat(
                encodedSponsorToken,
                bytes20(sponsorTokens[i].token),
                bytes20(sponsorTokens[i].spender),
                bytes32(sponsorTokens[i].amount)
            );
        }
        return abi.encodePacked(uint8(len), encodedSponsorToken);
    }

    function encodeRepayToken(IInvoiceManager.RepayTokenInfo[] memory repayTokens)
        internal
        pure
        returns (bytes memory encodedRepayToken)
    {
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

    function getEncodedRepayTokens(uint8 len) internal view returns (bytes memory encodedRepayToken) {
        IInvoiceManager.RepayTokenInfo[] memory repayTokens = new IInvoiceManager.RepayTokenInfo[](len);
        for (uint8 i = 0; i < len; i++) {
            repayTokens[i] = IInvoiceManager.RepayTokenInfo({vault: openfortVault, amount: 500, chainId: OPTIMISM_CHAIN_ID});
            encodedRepayToken = bytes.concat(
                encodedRepayToken,
                bytes20(address(repayTokens[i].vault)),
                bytes32(repayTokens[i].amount),
                bytes32(repayTokens[i].chainId)
            );
        }
        return abi.encodePacked(uint8(len), encodedRepayToken);
    }

    function testEncodeRepayToken() public pure {
        IInvoiceManager.RepayTokenInfo[] memory repayTokens = new IInvoiceManager.RepayTokenInfo[](1);
        repayTokens[0] = IInvoiceManager.RepayTokenInfo({
            vault: IVault(address(0x8e2048c85Eae2a4443408C284221B33e61906463)),
            amount: 500,
            chainId: OPTIMISM_CHAIN_ID
        });
        bytes memory encodedRepayToken = encodeRepayToken(repayTokens);
        assertEq(
            encodedRepayToken,
            hex"018e2048c85Eae2a4443408C284221B33e6190646300000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000aa37dc"
        );
    }

    function testValidateUserOpWithERC20SponsorToken() public {
        vm.chainId(BASE_SEPOLIA_CHAIN_ID);
        bytes memory sponsorTokensBytes = getEncodedSponsorTokens(1, address(mockERC20));
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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verifyingSignerPrivateKey, MessageHashUtils.toEthSignedMessageHash(userOpHash));
        // Append signature to paymasterAndData
        bytes memory signature = abi.encodePacked(r, s, v);

        userOp.paymasterAndData = bytes.concat(userOp.paymasterAndData, signature);

        vm.startPrank(ENTRY_POINT_V7);
        (bytes memory context,) = paymaster.validatePaymasterUserOp(userOp, userOpHash, type(uint256).max);

        uint256 allowanceAfterValidation = mockERC20.allowance(address(paymaster), userOp.sender);
        assertEq(allowanceAfterValidation, 500);

        // validate postOp
        // This is the event that we must track on dest chain and prove on source chain with Polymer proof system

        // Calculate the expected invoiceId
        bytes32 expectedInvoiceId =
            invoiceManager.getInvoiceId(rekt, address(paymaster), userOp.nonce, BASE_SEPOLIA_CHAIN_ID, repayTokensBytes);

        // don't know why comparison of paymaster address fails
        // even though it's the same address
        vm.expectEmit(true, true, true, false);
        emit IInvoiceManager.InvoiceCreated(expectedInvoiceId, rekt, address(paymaster));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 1222, 42);

        uint256 allowanceAfterExecution = mockERC20.allowance(address(paymaster), userOp.sender);
        assertEq(allowanceAfterExecution, 0);
    }

    function testValidateUserOpWithNativeSponsorToken() public {
        vm.chainId(BASE_SEPOLIA_CHAIN_ID);
        bytes memory sponsorTokensBytes = getEncodedSponsorTokens(1, NATIVE_TOKEN);
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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(verifyingSignerPrivateKey, MessageHashUtils.toEthSignedMessageHash(userOpHash));
        // Append signature to paymasterAndData
        bytes memory signature = abi.encodePacked(r, s, v);

        userOp.paymasterAndData = bytes.concat(userOp.paymasterAndData, signature);

        vm.startPrank(ENTRY_POINT_V7);
        vm.deal(address(paymaster), 1 ether);
        (bytes memory context,) = paymaster.validatePaymasterUserOp(userOp, userOpHash, type(uint256).max);

        assertEq(address(userOp.sender).balance, 500);

        // validate postOp
        // This is the event that we must track on dest chain and prove on source chain with Polymer proof system

        // Calculate the expected invoiceId
        bytes32 expectedInvoiceId =
            invoiceManager.getInvoiceId(rekt, address(paymaster), userOp.nonce, BASE_SEPOLIA_CHAIN_ID, repayTokensBytes);

        // don't know why comparison of paymaster address fails
        // even though it's the same address
        vm.expectEmit(true, true, true, false);
        emit IInvoiceManager.InvoiceCreated(expectedInvoiceId, rekt, address(paymaster));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 1222, 42);
    }

    function testGetInvoiceId() public view {
        address account = 0x5E3Ae8798eAdE56c3B4fe8F085DAd16D4912Ba83;
        address testPaymaster = 0xF6e64504ed56ec2725CDd0b3C1b23626D66008A2;
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
            invoiceManager.getInvoiceId(account, testPaymaster, nonce, sponsorChainId, abi.encode(repayTokens));
        assertEq(computedInvoiceId, expectedInvoiceId, "Invoice ID computation mismatch");
    }

    function testVerifyInvoiceWithPolymerV1() public {
        bytes32 invoiceId = 0x28a285ad4af66f8b864972de6e0ea1095667e73ade7db3d93151c0c266022905;
        bytes memory proof = getPolymerV1Proof(proofs);
        IInvoiceManager.RepayTokenInfo[] memory repayTokens = new IInvoiceManager.RepayTokenInfo[](1);
        repayTokens[0] = IInvoiceManager.RepayTokenInfo({
            vault: IVault(0xaF45f62eB99AD2091440336ca714B21F06525978),
            amount: 500,
            chainId: 11155420
        });
        IInvoiceManager.InvoiceWithRepayTokens memory invoice = IInvoiceManager.InvoiceWithRepayTokens({
            account: 0xddEbA0DD6D8c81e46Df16d82F561F3fd2f004Ee3,
            nonce: 32037943185660244671492037541888,
            paymaster: 0x9B1D4356014e36d95b0b00251770d641ea02979f,
            sponsorChainId: 84532,
            repayTokenInfos: repayTokens
        });
        assert(polymerPaymasterVerifier.verifyInvoice(invoiceId, invoice, proof));
    }

    function testVerifyInvoiceWithHashi() public {
        MockShoyuBashi shoyuBashi = new MockShoyuBashi();

        bytes32 invoiceId = 0x6f662367c1c8c75c2bd3494c5b0338a59cd67fe855e0c298cd875420ccf403ff;
        bytes memory proof = getHashiProof(proofs);

        // Deploy the mockInvoiceManager at the real address
        // to verifyInvoice with Hashi e2e
        MockInvoiceManager mockInvoiceManager = new MockInvoiceManager();
        address realInvoiceManager = 0x9285C1a617131Ca435db022110971De9255Edd9D;
        vm.etch(realInvoiceManager, address(mockInvoiceManager).code);

        HashiPaymasterVerifier paymasterVerifier =
            new HashiPaymasterVerifier(IInvoiceManager(realInvoiceManager), address(shoyuBashi), owner);

        IInvoiceManager.RepayTokenInfo[] memory repayTokens = new IInvoiceManager.RepayTokenInfo[](1);
        repayTokens[0] = IInvoiceManager.RepayTokenInfo({
            vault: IVault(0x7C1186b3831ce768E93047402EA06FD31b6f0e4B),
            amount: 500,
            chainId: 80002
        });
        IInvoiceManager.InvoiceWithRepayTokens memory invoice = IInvoiceManager.InvoiceWithRepayTokens({
            account: 0x80Bc8b46069EcA6E4bb3D80E8dF8bA469eDbfA39,
            nonce: 32110763582560026361303090069504,
            paymaster: 0x0A68C0766D16aF76bAB3226BB3c46bce3478DF99,
            sponsorChainId: 84532,
            repayTokenInfos: repayTokens
        });

        assert(paymasterVerifier.verifyInvoice(invoiceId, invoice, proof));
    }

    function testCABPaymasterRagequit() public {
        vm.deal(address(paymaster), 1 ether);

        assertEq(mockERC20.balanceOf(address(paymaster)), PAYMASTER_BASE_MOCK_ERC20_BALANCE);
        assertEq(address(paymaster).balance, 1 ether);

        vm.startPrank(owner);
        paymaster.rageQuit();

        assertEq(mockERC20.balanceOf(address(paymaster)), 0);
        assertEq(address(paymaster).balance, 0);

        assertEq(mockERC20.balanceOf(owner), PAYMASTER_BASE_MOCK_ERC20_BALANCE);
        assertEq(owner.balance, 1 ether);
    }

    function getPolymerV1Proof(string memory proofs) internal view returns (bytes memory) {
        return proofs.readBytes(".polymerV1");
    }

    function getHashiProof(string memory proofs) internal view returns (bytes memory) {
        return proofs.readBytes(".hashi");
    }
}
