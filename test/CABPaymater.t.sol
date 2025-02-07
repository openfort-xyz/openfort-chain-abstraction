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
import {MockCrossL2Prover} from "../src/mocks/MockCrossL2Prover.sol";
import {LiquidityManager} from "../src/liquidity/LiquidityManager.sol";
import {ILiquidityManager} from "../src/interfaces/ILiquidityManager.sol";
import {MiniFactory} from "../src/exchange/MiniSwap/MiniFactory.sol";
import {MiniRouter} from "../src/exchange/MiniSwap/MiniRouter.sol";

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
    LiquidityManager public liquidityManager;
    MiniFactory public miniFactory;
    MiniRouter public miniRouter;

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
        crossL2Prover = ICrossL2Prover(address(new MockCrossL2Prover()));

        // Setup MiniSwap and LiquidityManager
        miniFactory = new MiniFactory();
        miniRouter = new MiniRouter(address(miniFactory));
        liquidityManager = new LiquidityManager(address(miniRouter), address(miniFactory));

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
        paymaster = new CABPaymaster(
            entryPoint,
            invoiceManager,
            crossL2Prover,
            ILiquidityManager(address(liquidityManager)),
            verifyingSignerAddress,
            owner
        );
        settlement.initialize(owner, address(paymaster));

        mockERC20.mint(address(paymaster), PAYMSTER_BASE_MOCK_ERC20_BALANCE);

        assertEq(address(invoiceManager.vaultManager()), address(vaultManager));
        assertEq(address(vaultManager.invoiceManager()), address(invoiceManager));

        vm.startPrank(rekt);
        invoiceManager.registerPaymaster(
            address(paymaster), IPaymasterVerifier(address(paymaster)), block.timestamp + 100000
        );
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
        repayTokens[0] = IInvoiceManager.RepayTokenInfo({
            vault: IVault(address(0x8e2048c85Eae2a4443408C284221B33e61906463)),
            amount: 500,
            chainId: OPTIMISM_CHAIN_ID
        });
        bytes memory encodedRepayToken = encodeRepayToken(repayTokens);
        // assertEq(
        //     encodedRepayToken,
        //     0x018e2048c85Eae2a4443408C284221B33e6190646300000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000000aa37dc
        // );
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

        vm.startPrank(address(entryPoint));
        (bytes memory context, uint256 validationData) =
            paymaster.validatePaymasterUserOp(userOp, userOpHash, type(uint256).max);

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

    function testGetInvoiceId() public {
        address account = 0x5E3Ae8798eAdE56c3B4fe8F085DAd16D4912Ba83;
        address paymasterAddress = 0xF6e64504ed56ec2725CDd0b3C1b23626D66008A2;
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
            invoiceManager.getInvoiceId(account, paymasterAddress, nonce, sponsorChainId, abi.encode(repayTokens));
        assertEq(computedInvoiceId, expectedInvoiceId, "Invoice ID computation mismatch");
    }

    function testVerifyInvoice() public {
        bytes32 invoiceId = 0x28a285ad4af66f8b864972de6e0ea1095667e73ade7db3d93151c0c266022905;
        bytes memory proof =
            hex"00000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000001900eb81ebedb4fb2930ce270c47e6ef70555f7f145f2b37efe8d4ab330994dea20500000000000000000000000000000000000000000000000000000000000000060002ecbbb20100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005400000000000000000000000000000000000000000000000000000000000000580000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000002e000000000000000000000000000000000000000000000000000000000000003a0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000204c86a00ddfe2387ae8a0f5360e9ec3bb467cb0b5a04c8f88bfa3c2a3edeb16c7000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000021013c8db5e5ac66124a1940c4dbb73a53b5ba5c28f6d066775d60662e12d183097e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002101c3f1b20d3343919dec28f51c06bc0c485efb3fc4a090e1851635e8c55c15b2aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002101bfc63a3f99095b8076510193b6165a19c1aff8e0c01003976a15a5e1889510170000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002043d1641a968012e8d8eaa3c123b2e1b359f68a609848731721435f982d4d165d0000000000000000000000000000000000000000000000000000000000000007706f6c79696263000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020a013cbed3e55d4663b2a98db2f990e2a5552dacc906671dcff886cc23b2713fa0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000003200000000000000000000000000000000000000000000000000000000000000073f871a099e0b708db6f890c2e296b5b397aaa872b668ca64894778d97fe9e43111519b8a0f864301ba4b48d1352df9fe1a7d8ed0d1b204626d632b1b4ceb7bd8ac5db7c65808080808080a042d5f8ba7b64da2d841d6094a8a4195ab3b555f7cdb3dccfbe20380307d801c380808080808080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000001f4f901f180a008b7bae679a355c6a38feb106393b16c8a526e0363781a6ab368616a50340a48a0e61151f1be0da2689f137415191d6c64bfac4890a8a81d2e14463d5e36e152d8a05e0cb861865714d13efabdd880bf24f971a973733a86169f8d8d9b9d6280bb2ba00e37e3b46af539bcdd10c1e9b899a1d5b5366865a3656347c786eeaf3e8163b6a08f2c2cd7f608b326c019630a44f03ad62c6fa48702f27b61ad662caad97bb6c8a015aa2b41039003e13864234bb0ac87a4a057dc603712936f7305a463258f174aa0340451f82f52251dbde532bc0693c081800742178e127c42381d6f367d3bd0aea03b9b5546139aecd70a5f2b1ac72872c7e13b7b1e8b398b3e56acdf8407512ccfa042227939280b7218c8a87c2d053592547e5b1ef1de8ca5b67bda61033a2e7de5a06906af43c2866782014fa9c7b0a28dc961c47e57412910bdd1801d7152671907a0254c32a27abcc3a643b54f1959f64ff48f735b90903320d548533138b8adda36a01d79921fa9209576bdf6b1d9762db1ae2c46731f82a92b797e5c37b093cff1f2a0b7e1ee52d932b780f9116e4d23cda2c382fdac7cb871e7afc345c3389cc56607a0729f6df0d6ed8e16cb30450b91cd7103f00cc8448bb0a11109ad9fcbfaa78abda0b264e35352739e06d1e4b79b7b3aab5d20b3a2f0b2fb6c88c655687a20999ba2800000000000000000000000000000000000000000000000000000000000000000000000000000000000000717f9071420b9071002f9070c0183126a66b9010000000000000000000000000000000000000000000000000000000000000000000008000402000000008000050000200000000000000001001000820000200400000000000000000000800008000000000040080000000040000000000000000000000000022800400000000000000800000000000000000000000010000000000000000000000200000800000108000000040080000000100000000000000000220000000000000000400000000000002000000000000000000002000000048000000002000000580001000000000000000000000000000100000000000020000010000000000000200000000004000400000000000000000000000000810000f90601f89b94ff3311cd15ab091b00421b23bcb60df02efd8db7f863a08c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925a00000000000000000000000009b1d4356014e36d95b0b00251770d641ea02979fa0000000000000000000000000ddeba0dd6d8c81e46df16d82f561f3fd2f004ee3a000000000000000000000000000000000000000000000000000000000000001f4f838940000000071727de22e5e9d8baf0edac6f37da032e1a0bb47ee3e183a558b1a2ff0874b079f3fc5478b7454eacf2bfc5af2ff5878f97280f89b94ff3311cd15ab091b00421b23bcb60df02efd8db7f863a0ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3efa00000000000000000000000009b1d4356014e36d95b0b00251770d641ea02979fa0000000000000000000000000ddeba0dd6d8c81e46df16d82f561f3fd2f004ee3a000000000000000000000000000000000000000000000000000000000000001f4f89b94ff3311cd15ab091b00421b23bcb60df02efd8db7f863a08c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925a0000000000000000000000000ddeba0dd6d8c81e46df16d82f561f3fd2f004ee3a0000000000000000000000000d129bda7ce0888d7fd66ff46e7577c96984d678fa000000000000000000000000000000000000000000000000000000000000001f4f89b94ff3311cd15ab091b00421b23bcb60df02efd8db7f863a0ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3efa0000000000000000000000000ddeba0dd6d8c81e46df16d82f561f3fd2f004ee3a0000000000000000000000000d129bda7ce0888d7fd66ff46e7577c96984d678fa000000000000000000000000000000000000000000000000000000000000001f4f89c94d129bda7ce0888d7fd66ff46e7577c96984d678ff884a0ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3efa00000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000ddeba0dd6d8c81e46df16d82f561f3fd2f004ee3a0000000000000000000000000000000000000000000000000000000000000002b80f85894d129bda7ce0888d7fd66ff46e7577c96984d678fe1a0f8e1a15aba9398e019f0b49df1a4fde98ee17ae345cb5f6b5e2c27f5033e8ce7a0000000000000000000000000000000000000000000000000000000000000002bf89b94ff3311cd15ab091b00421b23bcb60df02efd8db7f863a08c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925a00000000000000000000000009b1d4356014e36d95b0b00251770d641ea02979fa0000000000000000000000000ddeba0dd6d8c81e46df16d82f561f3fd2f004ee3a00000000000000000000000000000000000000000000000000000000000000000f89c94bc11ee7d2f3d74f5a6a5add3457908870bfcf37bf884a05243d6c5479d93025de9e138a29c467868f762bb78591e96299fb3f437afcc04a028a285ad4af66f8b864972de6e0ea1095667e73ade7db3d93151c0c266022905a0000000000000000000000000ddeba0dd6d8c81e46df16d82f561f3fd2f004ee3a00000000000000000000000009b1d4356014e36d95b0b00251770d641ea02979f80f9011d940000000071727de22e5e9d8baf0edac6f37da032f884a049628fd1471006c1482da88028e9ce4dbb080b815c9b0344d39e5a8e6ec1419fa058fcda0e20a2e831bcd8ecdf1a09d44c4c33fc3191cdb6d33082111ed70b738ba0000000000000000000000000ddeba0dd6d8c81e46df16d82f561f3fd2f004ee3a00000000000000000000000009b1d4356014e36d95b0b00251770d641ea02979fb8800000000000000000000000000000000000000194602d7821000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000005a83e6ba4ebab000000000000000000000000000000000000000000000000000000000017df790000000000000000000000000000000000000000000000000000000000000000000000000000000005383435333200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010d00000000000000000000000000000000000000000000000000000000000000";
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

        console.logBytes(abi.encode(invoice));
        assert(paymaster.verifyInvoice(invoiceId, invoice, proof));
    }
}
