import { PaymasterActions, GetPaymasterDataParameters, GetPaymasterDataReturnType, GetPaymasterStubDataParameters, GetPaymasterStubDataReturnType, UserOperation, PackedUserOperation } from "viem/account-abstraction";
import { chainIDs, paymasters, paymasterVerifier, supportedChain, tokenA, vaultA } from "./constants";
import { Hex, keccak256, encodeAbiParameters, Address, concat, encodePacked, numberToHex, pad, toHex } from "viem";
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

            const hash = await computeHash(userOp, chain, validUntil, validAfter);
            const signature = await paymasterVerifier.sign({ hash });
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
        },
    };
}


async function computeHash(userOp: PackedUserOperation, chain: supportedChain, validUntil: bigint, validAfter: bigint) {
    const encodedData = concat([
        userOp.sender,
        pad(numberToHex(userOp.nonce), { size: 32 }),
        keccak256(userOp.initCode),
        keccak256(userOp.callData),
        userOp.accountGasLimits,
        keccak256(concat([getRepayToken(userOp.sender), getSponsorTokens(userOp.sender, chain)])),
        toHex(BigInt(encodePacked(["uint128", "uint128"], [userOp.preVerificationGas, 100000n])), { size: 32 }),
        pad(numberToHex(userOp.preVerificationGas), { size: 16 }),
        userOp.gasFees,
        pad(numberToHex(chainIDs[chain]), { size: 32 }),
        paymasters[chain] as Address,
        pad(numberToHex(validUntil), { size: 6 }),
        pad(numberToHex(validAfter), { size: 6 })
    ]);

    const hash = keccak256(encodedData);
    return hash;
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