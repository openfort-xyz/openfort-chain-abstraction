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

        (, IInvoiceManager.RepayTokenInfo[] memory repayTokens) = paymaster.parseRepayTokenData(repayTokensBytes);
        // validate postOp
        // This is the event that we must track on dest chain and prove on source chain with Polymer proof system
        vm.expectEmit();
        emit IPaymasterVerifier.InvoiceCreated(
            invoiceManager.getInvoiceId(rekt, address(paymaster), userOp.nonce, BASE_SEPOLIA_CHAIN_ID, repayTokens)
        );
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 1222, 42);
    }

    function testPaymasterSigRecover() public {
        bytes memory signature = hex"62cf09218852fa9f7dfba892a7813a4ea8f03e8b4459b15dc0a7557bc4cb7cc800bead31b530d2f80644bb94bd491e0a660c91382b09d534e0f7f864da4c01db1b";
        bytes32 hash = 0x0516f2ecbc851514607eadb71b63c15ff0a3fdde5f661fcdf6e412dfd4396073;
        address recovered = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(hash), signature);
        assertEq(recovered, rekt);
    }

//     function testGetHash() public {
//         uint48 validUntil = 20379348;
//         uint48 validAfter = 19379348;

//         PackedUserOperation memory userOp = PackedUserOperation({
//             sender: 0xFb619E988fD324734be51b0475A67b6921D0301f,
//             nonce: 31996375400717808072039644266496,
//             initCode: hex"91E60e0613810449d098b0b5Ec8b51A0FE8c89855fbfb9cf0000000000000000000000009590ed0c18190a310f4e93caccc4cc17270bed400000000000000000000000000000000000000000000000000000000000000000",
//             callData: hex"47e1da2a000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000003000000000000000000000000ff3311cd15ab091b00421b23bcb60df02efd8db7000000000000000000000000ff3311cd15ab091b00421b23bcb60df02efd8db7000000000000000000000000d129bda7ce0888d7fd66ff46e7577c96984d678f00000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000006423b872dd000000000000000000000000f6e64504ed56ec2725cdd0b3c1b23626d66008a2000000000000000000000000fb619e988fd324734be51b0475a67b6921d0301f0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b3000000000000000000000000d129bda7ce0888d7fd66ff46e7577c96984d678f00000000000000000000000000000000000000000000000000000000000001f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084d85d3d270000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003b6261667962656965346636336c7935676a6471346c676d74336e33346f67637a716d757277663275326e756b693366747073613679636a79677865000000000000000000000000000000000000000000000000000000000000000000",
//             accountGasLimits: 0x000000000000000000000000000f4240000000000000000000000000000f4240,
//             preVerificationGas: 1000000,
//             gasFees: 0x0000000000000000000000003b9aca00000000000000000000000000b2d05e00,
//             paymasterAndData: hex"F6e64504ed56ec2725CDd0b3C1b23626D66008A2000000000000000000000000000f4240000000000000000000000000000186a000000136f6d400000127b494018e2048c85Eae2a4443408C284221B33e6190646300000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000aa37dc01fF3311cd15aB091B00421B23BcB60df02EFD8db7Fb619E988fD324734be51b0475A67b6921D0301f00000000000000000000000000000000000000000000000000000000000001f4469cfb36ee62bf829b1a21065b34fad76f69fc458ef15aef644db820e87880e91e9fc86ebe6112b1ad52f5cf050f63cabf35c42328886d54dba63d7912cbb7461b",
//             signature: hex"47140b77612d9ea6bb0d7175ae8c91ea693e4e231fb48ae499c45d0a9309a42735de448da6ce53a4f195607a9afb7a4a21d5ae78c20cff808702d4e892a082ee1b"
//         });

//         vm.chainId(BASE_SEPOLIA_CHAIN_ID);
//         bytes32 hash = paymaster.getHash(userOp, validUntil, validAfter);
//         console.log("getHash returns:");
//         console.logBytes32(hash);

//         /*
//     cast call 0xF6e64504ed56ec2725CDd0b3C1b23626D66008A2 "getHash((address,uint256,bytes,bytes,bytes32,uint256,bytes32,bytes,bytes),uint48,uint48)" "(0xFb619E988fD324734be51b0475A67b6921D0301f,31996375400717808072039644266496,0x91E60e0613810449d098b0b5Ec8b51A0FE8c89855fbfb9cf0000000000000000000000009590ed0c18190a310f4e93caccc4cc17270bed400000000000000000000000000000000000000000000000000000000000000000,0x47e1da2a000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000003000000000000000000000000ff3311cd15ab091b00421b23bcb60df02efd8db7000000000000000000000000ff3311cd15ab091b00421b23bcb60df02efd8db7000000000000000000000000d129bda7ce0888d7fd66ff46e7577c96984d678f000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000
// 00000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000006423b872dd000000000000000000000000f6e64504ed56ec2725cdd0b3c1b23626d66008a2000000000000000000000000fb619e988fd324734be51b0475a67b6921d0301f0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b3000000000000000000000000d129bda7ce0888d7fd66ff46e7577c96984d678f0000000000000000000000000000000000000000000000000
// 0000000000001f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084d85d3d270000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003b6261667962656965346636336c7935676a6471346c676d74336e33346f67637a716d757277663275326e756b693366747073613679636a79677865000000000000000000000000000000000000000000000000000000000000000000","0x000000000000000000000000000f4240000000000000000000000000000f4240,1000000,0x0000000000000000000000003b9aca00000000000000000000000000b2d05e00,0xF6e64504ed56ec2725CDd0b3C1b23626D66008A2000000000000000000000000000f4240000000000000000000000000000186a000000136f6d400000127b494018e2048c85Eae2a4443408C284221B33e6190646300000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000aa37dc01fF3311cd15aB091B00421B23BcB60df02EFD8db7Fb619E988fD324734be51b0475A67b6921D0301f00000000000000000000000000000000000000000000000000000000000001f4469cfb36ee62bf829b1a21065b34fad76f69fc458ef15aef644db820e87880e91e9fc86ebe6112b1ad52f5cf050f63cabf35c42328886d54dba63d7912cbb7461b,0x47140b77612d9ea6bb0d7175ae8c91ea693e4e231fb48ae499c45d0a9309a42735de448da6ce53a4f195607a9afb7a4a21d5ae78c20cff808702d4e892a082ee1b)" 20379348 19379348 --rpc-url https://sepolia.base.org

//                    ==> 0x88800f0c29d6ba24fa635822ff4098e15b23048a57eec551b4a3af752aab97cd

//         */
//         // NEED TO MOCK paymaster address to pass the proof: 0xF6e64504ed56ec2725CDd0b3C1b23626D66008A2!!!
//         assert(hash == 0x88800f0c29d6ba24fa635822ff4098e15b23048a57eec551b4a3af752aab97cd);
//     }

}

