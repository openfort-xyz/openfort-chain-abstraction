import {
  Address,
  concat,
  encodeAbiParameters,
  getAddress,
  Hex,
  keccak256,
  numberToHex,
  pad,
  parseAbi,
  toHex,
} from "viem";
import { publicClients } from "./viemClients";
import {
  chainIDs,
  paymasters,
  supportedChain,
  tokenA,
  vaultA,
} from "./constants";
import { PackedUserOperation } from "viem/account-abstraction";

export async function getBlockTimestamp(chain: supportedChain) {
  const block = await publicClients[chain].getBlock();
  return block.timestamp;
}

export function computeHash(
  userOp: PackedUserOperation,
  chain: supportedChain,
  validUntil: bigint,
  validAfter: bigint,
  paymasterVerificationGasLimit: bigint,
  paymasterPostOpGasLimit: bigint,
) {
  const repayTokenData = getRepayToken(userOp.sender);
  const sponsorTokenData = getSponsorTokens(userOp.sender, chain);
  const encodedTokenData = encodeAbiParameters(
    [{ type: "bytes" }, { type: "bytes" }],
    [repayTokenData, sponsorTokenData],
  );
  const gasInfo = concat([
    pad(toHex(paymasterVerificationGasLimit || 0n), { size: 16 }),
    pad(toHex(paymasterPostOpGasLimit || 0n), { size: 16 }),
  ]);
  const encodedData = encodeAbiParameters(
    [
      { type: "address", name: "sender" },
      { type: "uint256", name: "nonce" },
      { type: "bytes32", name: "initCodeHash" },
      { type: "bytes32", name: "callDataHash" },
      // { type: "bytes32", name: "accountGasLimits" },
      { type: "bytes32", name: "tokensHash" },
      { type: "bytes32", name: "gasInfo" },
      { type: "uint256", name: "preVerificationGas" },
      { type: "bytes32", name: "gasFees" },
      { type: "uint256", name: "chainId" },
      { type: "address", name: "paymaster" },
      { type: "uint48", name: "validUntil" },
      { type: "uint48", name: "validAfter" },
    ],
    [
      getAddress(userOp.sender),
      userOp.nonce,
      pad(keccak256(userOp.initCode), { size: 32 }),
      keccak256(userOp.callData),
      // pad(userOp.accountGasLimits, { size: 32 }),
      keccak256(encodedTokenData),
      pad(gasInfo as Hex, { size: 32 }),
      userOp.preVerificationGas,
      pad(userOp.gasFees, { size: 32 }),
      BigInt(chainIDs[chain]),
      getAddress(paymasters[chain]),
      Number(validUntil),
      Number(validAfter),
    ],
  );
  return keccak256(encodedData);
}

export function getRepayToken(sender: Address) {
  // TODO: check sender locked-funds
  return concat([
    "0x01", // length of the array (only one repay token)
    vaultA["optimism"] as Address,
    pad(numberToHex(500), { size: 32 }),
    pad(numberToHex(chainIDs["optimism"]), { size: 32 }),
  ]);
}

export function getSponsorTokens(spender: Address, chain: supportedChain) {
  return concat([
    "0x01", // length of the array (only one sponsor token)
    tokenA[chain] as Address,
    spender,
    pad(numberToHex(500), { size: 32 }), // 500 (the NFT Price)
  ]);
}
