import {
  PaymasterActions,
  GetPaymasterDataParameters,
  GetPaymasterDataReturnType,
  GetPaymasterStubDataParameters,
  GetPaymasterStubDataReturnType,
  PackedUserOperation,
} from "viem/account-abstraction";
import {
  openfortContracts,
  paymasterVerifierAccount,
  supportedChain,
} from "./constants";
import {
  Hex,
  Address,
  concat,
  numberToHex,
  getAddress,
  toHex,
  pad,
} from "viem";
import {
  computeHash,
  getBlockTimestamp,
  getRepayTokens,
  getSponsorTokens,
  isAdminCall,
} from "./utils";

export function getPaymasterActions(chain: supportedChain): PaymasterActions {
  return {
    getPaymasterData: async (
      parameters: GetPaymasterDataParameters,
    ): Promise<GetPaymasterDataReturnType> => {
      const isAdminCallCache = isAdminCall(parameters.callData);
      const pmAddress = isAdminCallCache
        ? openfortContracts[chain].adminPaymaster
        : openfortContracts[chain].cabPaymaster;
      const currentBlockTimestamp = await getBlockTimestamp(chain);
      const validAfter = currentBlockTimestamp - 1_000_000n;
      const validUntil = currentBlockTimestamp + 1_000_000n;
      const postVerificationGas =
        parameters.paymasterPostOpGasLimit || BigInt(1e5);
      const verificationGasLimit =
        parameters.verificationGasLimit || BigInt(1e5);
      const callGasLimit = parameters.callGasLimit || BigInt(1e5);
      const userOp: PackedUserOperation = {
        accountGasLimits: getAccountGasLimits(
          verificationGasLimit,
          callGasLimit,
        ),
        gasFees: getGasLimits(
          parameters.maxPriorityFeePerGas!,
          parameters.maxFeePerGas!,
        ),
        preVerificationGas: parameters.preVerificationGas || BigInt(0),
        callData: parameters.callData,
        nonce: parameters.nonce,
        sender: parameters.sender,
        signature: "0x",
        initCode: getInitCode(parameters.factory, parameters.factoryData),
        paymasterAndData: "0x",
      };

      const hash = await computeHash(
        userOp,
        chain,
        validUntil,
        validAfter,
        verificationGasLimit,
        postVerificationGas,
      );
      const signature = await paymasterVerifierAccount.signMessage({
        message: { raw: hash },
      });

      return {
        paymaster: getAddress(pmAddress),
        paymasterData: isAdminCallCache
          ? "0x"
          : (concat([
              numberToHex(validUntil, { size: 6 }),
              numberToHex(validAfter, { size: 6 }),
              getRepayTokens(userOp.sender, "polygon"), // DEMO: repay with polygon token
              getSponsorTokens(userOp.sender, chain),
              signature,
            ]) as Hex),
        paymasterVerificationGasLimit: verificationGasLimit,
        paymasterPostOpGasLimit: postVerificationGas,
      };
    },
    getPaymasterStubData: async (
      parameters: GetPaymasterStubDataParameters,
    ): Promise<GetPaymasterStubDataReturnType> => {
      const pmAddress = isAdminCall(parameters.callData)
        ? openfortContracts[chain].adminPaymaster
        : openfortContracts[chain].cabPaymaster;

      return {
        paymaster: getAddress(pmAddress),
        paymasterData: (
          await getPaymasterActions(chain).getPaymasterData(parameters)
        ).paymasterData as Hex,
        paymasterPostOpGasLimit: BigInt(1e6),
        paymasterVerificationGasLimit: BigInt(1e6),
      };
    },
  };
}

function getInitCode(
  factory: Address | undefined,
  factoryData: Hex | undefined,
) {
  return factory ? concat([factory, factoryData || ("0x" as Hex)]) : "0x";
}

function getAccountGasLimits(
  verificationGasLimit: bigint,
  callGasLimit: bigint,
) {
  return concat([
    pad(toHex(verificationGasLimit), {
      size: 16,
    }),
    pad(toHex(callGasLimit), { size: 16 }),
  ]);
}

function getGasLimits(maxPriorityFeePerGas: bigint, maxFeePerGas: bigint) {
  return concat([
    pad(toHex(maxPriorityFeePerGas), {
      size: 16,
    }),
    pad(toHex(maxFeePerGas), { size: 16 }),
  ]);
}
