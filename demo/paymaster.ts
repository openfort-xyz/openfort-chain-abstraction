import { PaymasterActions, GetPaymasterDataParameters, GetPaymasterDataReturnType, GetPaymasterStubDataParameters, GetPaymasterStubDataReturnType, UserOperation, PackedUserOperation } from "viem/account-abstraction";
import { paymasters, paymasterVerifier, supportedChain } from "./constants";
import { Hex, Address, concat, numberToHex, getAddress } from "viem";
import { computeHash, getBlockNumber, getRepayToken, getSponsorTokens } from "./utils";



export function getPaymasterActions(chain: supportedChain): PaymasterActions {
    const pmAddress = paymasters[chain] as Address;
    return {
        getPaymasterData: async (parameters: GetPaymasterDataParameters): Promise<GetPaymasterDataReturnType> => {


            const validAfter = await getBlockNumber(chain);
            const validUntil = validAfter + 1000000n;
            // TODO: get it from the parameters
            const postVerificationGas = 100000n;
            const verificationGasLimit = parameters.verificationGasLimit || BigInt(1e5);
            const callGasLimit = parameters.callGasLimit || BigInt(1e5);

            const accountGasLimits = `0x${verificationGasLimit.toString(16)}${callGasLimit.toString(16)}` as Hex;
            const gasFees = `0x${parameters.maxFeePerGas!.toString(16)}${parameters.maxPriorityFeePerGas!.toString(16)}` as Hex;
            const userOp: PackedUserOperation = {
                accountGasLimits: accountGasLimits,
                gasFees: gasFees,
                preVerificationGas: parameters.preVerificationGas || BigInt(0),
                callData: parameters.callData,
                nonce: parameters.nonce,
                sender: parameters.sender,
                signature: "0x",
                initCode: parameters.initCode || "0x",
                paymasterAndData: "0x",
            };
            const hash = await computeHash(userOp, chain, validUntil, validAfter);
            const signature = await paymasterVerifier.signMessage({ message: hash });
            console.log("signature", signature);
            return {
                paymaster: getAddress(pmAddress),
                paymasterData: concat([
                    numberToHex(validUntil, { size: 6 }),
                    numberToHex(validAfter, { size: 6 }),
                    getRepayToken(userOp.sender),
                    getSponsorTokens(userOp.sender, chain),
                    signature
                ]) as Hex,
                paymasterVerificationGasLimit: verificationGasLimit,
                paymasterPostOpGasLimit: postVerificationGas,
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