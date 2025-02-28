import {
  Address,
  concat,
  encodeAbiParameters,
  getAddress,
  Hex,
  keccak256,
  numberToHex,
  pad,
  toHex,
  decodeFunctionData,
  parseAbi,
} from "viem";
import { publicClients } from "./viemClients";
import {
  chainIDs,
  openfortContracts,
  supportedChain,
  tokenA,
  vaultA,
} from "./constants";
import { PackedUserOperation } from "viem/account-abstraction";

export async function getBlockTimestamp(chain: supportedChain) {
  const block = await publicClients[chain].getBlock();
  return block.timestamp;
}

export async function getBlockNumber(chain: supportedChain) {
  const block = await publicClients[chain].getBlockNumber();
  return block;
}

export async function getLogIndex(txHash: Hex, chain: supportedChain) {
  // InvoiceManager.InvoiceCreated.selector
  const invoiceCreatedSelector =
    "0x5243d6c5479d93025de9e138a29c467868f762bb78591e96299fb3f437afcc04";
  const txReceipt = await publicClients[chain].getTransactionReceipt({
    hash: txHash,
  });
  const localLogIndex = txReceipt.logs.findIndex(
    (log) => log.topics[0] === invoiceCreatedSelector,
  );
  return localLogIndex;
}

export function isAdminCall(callData: Hex) {
  // Note: admin methods requires msg.sender to be the smart account address
  // and DemoAdminPaymaster sponsors the calls

  // InvoiceManager: registerPaymaster, revokePaymaster
  const adminSelectors = ["0xa23f2985", "0x1b8003c7"];

  try {
    const decoded = decodeFunctionData({
      data: callData,
      abi: parseAbi(["function execute(address, uint256, bytes)"]),
    });
    const selector = decoded.args[2].slice(0, 10);
    return adminSelectors.includes(selector);
  } catch (error) {
    // Note: executeBatch doesn't support admin calls
    return false;
  }
}

export function computeHash(
  userOp: PackedUserOperation,
  chain: supportedChain,
  validUntil: bigint,
  validAfter: bigint,
  paymasterVerificationGasLimit: bigint,
  paymasterPostOpGasLimit: bigint,
) {
  // NOTE: hardcoded repay on polygon for demo purposes
  const repayTokenData = getRepayTokens(userOp.sender, "polygon");
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
      getAddress(openfortContracts[chain].cabPaymaster),
      Number(validUntil),
      Number(validAfter),
    ],
  );
  return keccak256(encodedData);
}

export function getRepayTokens(sender: Address, chain: supportedChain) {
  // TODO: check sender locked-funds
  return concat([
    "0x01", // length of the array (only one repay token)
    vaultA[chain] as Address,
    pad(numberToHex(500), { size: 32 }), // DEMO: fixed amount tokens are repaid
    pad(numberToHex(chainIDs[chain]), { size: 32 }),
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
