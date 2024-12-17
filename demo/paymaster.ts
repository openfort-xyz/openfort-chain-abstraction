import { PaymasterActions, GetPaymasterDataParameters, GetPaymasterDataReturnType, GetPaymasterStubDataParameters, GetPaymasterStubDataReturnType, UserOperation, PackedUserOperation } from "viem/account-abstraction";
import { chainIDs, paymasters, paymasterVerifier, supportedChain, tokenA, vaultA } from "./constants";
import { Hex, keccak256, encodeAbiParameters, Address, concat, encodePacked, numberToHex, pad, toHex, toBytes,  } from "viem";
import { publicClients } from "./clients";



export function getPaymasterActions(chain: supportedChain): PaymasterActions {
    const pmAddress = paymasters[chain] as Address;
    return {
        getPaymasterData: async (parameters: GetPaymasterDataParameters): Promise<GetPaymasterDataReturnType> => {
            const validAfter = await publicClients[chain].getBlockNumber();
            const validUntil = validAfter + 1000000n;
            // only available for AA v7
            const postVerificationGas = 100000n;
            const verificationGasLimit = parameters.verificationGasLimit || BigInt(1e5);
            const callGasLimit = parameters.callGasLimit || BigInt(1e5);

            console.log("verificationGasLimit", verificationGasLimit);
            console.log("callGasLimit", callGasLimit);

            const userOp: PackedUserOperation = {
                accountGasLimits: `0x${verificationGasLimit.toString(16)}${callGasLimit.toString(16)}` as Hex,
                gasFees: `0x${parameters.maxFeePerGas!.toString(16)}${parameters.maxPriorityFeePerGas!.toString(16)}` as Hex,
                preVerificationGas: parameters.preVerificationGas || BigInt(0),
                callData: parameters.callData,
                nonce: parameters.nonce,
                sender: parameters.sender,
                signature: "0x",
                initCode: parameters.initCode || "0x",
                paymasterAndData: "0x",
            };

            console.log("pmAddress", pmAddress);
            console.log("userOp.preVerificationGas", numberToHex(userOp.preVerificationGas, { size: 16 }));
            console.log("postVerificationGas", numberToHex(postVerificationGas, { size: 16 }));
            console.log("validUntil", numberToHex(validUntil, { size: 6 }));
            console.log("validAfter", numberToHex(validAfter, { size: 6 }));
            const hash = await computeHash(userOp, chain, validUntil, validAfter);
            const signature = await paymasterVerifier.signMessage({ message: hash });
            return {
                paymasterAndData: concat([
                    pmAddress,
                    numberToHex(userOp.preVerificationGas, { size: 16 }),
                    numberToHex(postVerificationGas, { size: 16 }),
                    numberToHex(validUntil, { size: 6 }),
                    numberToHex(validAfter, { size: 6 }),
                    getRepayToken(userOp.sender),
                    getSponsorTokens(userOp.sender, chain),
                    signature
                ])
            };
        },
        getPaymasterStubData: async (
            parameters: GetPaymasterStubDataParameters,
        ): Promise<GetPaymasterStubDataReturnType> => {

            return {
                paymasterAndData: (await getPaymasterActions(chain).getPaymasterData(parameters)).paymasterAndData as Hex,
            };

            // Simulation reverts:  "transferFrom | approve | mint" reverted with the following signature": Insufficient allowance
            // return {
            //     paymasterAndData: "0x" as Hex,
            // };


            // return {
            //     paymasterAndData:
            //         `${pmAddress}00000000000000000000000000000000000000000000000000000000deadbeef000000000000000000000000000000000000000000000000000000000000123400000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002000000000000000000000000f62849f9a0b5bf2913b396098f7c7019b51a820a00000000000000000000000000000000000000000000000000000000009896803c3e4f3f2488eab12a788db10240c757d360350a2a3938f37237ddfe070d132a28796766b9f0ef1f04cd3678ac598d76c9bec7e70f11bfae500873879b2fead31b` as Hex,
            // };
        },
    };
}


async function computeHash(userOp: PackedUserOperation, chain: supportedChain, validUntil: bigint, validAfter: bigint) {

    console.log("userOp.sender", userOp.sender);
    console.log("userOp.nonce", userOp.nonce);
    console.log("userOp.initCode", userOp.initCode);
    console.log("userOp.callData", userOp.callData);
    console.log("userOp.accountGasLimits", userOp.accountGasLimits);
    console.log("getRepayToken(userOp.sender)", getRepayToken(userOp.sender));
    console.log("getSponsorTokens(userOp.sender, chain)", getSponsorTokens(userOp.sender, chain));

    console.log("pre/post verification gas");
    console.log(encodePacked(["uint128", "uint128"], [100000n, 100000n]));

    const encodedData = encodeAbiParameters(
        [
            { type: "address", name: "sender" },
            { type: "uint256", name: "nonce" },
            { type: "bytes32", name: "initCodeHash" },
            { type: "bytes32", name: "callDataHash" },
            { type: "bytes32", name: "accountGasLimits" },
            { type: "bytes32", name: "tokensHash" },
            { type: "bytes32", name: "gasInfo" },
            { type: "uint256", name: "preVerificationGas" },
            { type: "bytes32", name: "gasFees" },
            { type: "uint256", name: "chainId" },
            { type: "address", name: "paymaster" },
            { type: "uint48", name: "validUntil" },
            { type: "uint48", name: "validAfter" }
        ],
        [
            userOp.sender,
            userOp.nonce,
            keccak256(userOp.initCode),
            keccak256(userOp.callData),
            pad(userOp.accountGasLimits, { size: 32 }),
            keccak256(encodeAbiParameters(
                [{ type: "bytes" }, { type: "bytes" }],
                [getRepayToken(userOp.sender), getSponsorTokens(userOp.sender, chain)]
            )),
            encodePacked(["uint128", "uint128"], [userOp.preVerificationGas, 100000n]),
            userOp.preVerificationGas,
            pad(userOp.gasFees, { size: 32 }),
            BigInt(chainIDs[chain]),
            paymasters[chain] as Address,
            Number(validUntil),
            Number(validAfter)
        ]
    )


    console.log("encodedData", encodedData);
    const userOpHash = keccak256(encodedData);
    console.log("userOpHash", userOpHash);
    return userOpHash;
}

function getRepayToken(sender: Address) {
    // TODO: check sender locked-funds
    return concat([
        "0x01", // length of the array (only one repay token)
        vaultA["optimism"] as Address,
        pad(numberToHex(500), { size: 32 }),
        pad(numberToHex(chainIDs["optimism"]), { size: 32 })
    ])
}

function getSponsorTokens(spender: Address, chain: supportedChain) {
    return concat([
        "0x01", // length of the array (only one sponsor token)
        tokenA[chain] as Address,
        spender,
        pad(numberToHex(500), { size: 32 }) // 500 (the NFT Price)
    ])
}