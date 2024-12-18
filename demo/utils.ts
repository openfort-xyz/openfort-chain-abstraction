
import { Address, concat, encodeAbiParameters, encodePacked, getAddress, Hex, keccak256, numberToHex, pad } from "viem";
import { publicClients } from "./clients";
import { chainIDs, paymasters, supportedChain, tokenA, vaultA } from "./constants";
import { PackedUserOperation } from "viem/account-abstraction";

export async function getBlockNumber(chain: supportedChain) {
    return await publicClients[chain].getBlockNumber();
}


export function computeHash(userOp: PackedUserOperation, chain: supportedChain, validUntil: bigint, validAfter: bigint) {

    const repayTokenData = getRepayToken(userOp.sender);
    const sponsorTokenData = getSponsorTokens(userOp.sender, chain);
    console.log("userOp.sender", userOp.sender);
    console.log("userOp.nonce", userOp.nonce);
    console.log("userOp.initCode", userOp.initCode);
    console.log("userOp.callData", userOp.callData);
    console.log("preVerificationGas", userOp.preVerificationGas);
    console.log("gasFees", userOp.gasFees);
    // TODO: readd when readded in the CABPaymaster
    console.log("userOp.accountGasLimits", userOp.accountGasLimits);
    console.log("repayTokenData", repayTokenData);
    console.log("sponsorTokenData", sponsorTokenData);
    const encodedTokenData = encodeAbiParameters(
        [{ type: "bytes" }, { type: "bytes" }],
        [repayTokenData, sponsorTokenData]
    );
    console.log("encodedTokenData", encodedTokenData);
    const PAYMASTER_VALIDATION_GAS_OFFSET = 20;
    const PAYMASTER_DATA_OFFSET = 52;
    const gasInfo =  `0x${userOp.paymasterAndData.slice(2 + 2 * PAYMASTER_VALIDATION_GAS_OFFSET, 2 + 2 * PAYMASTER_DATA_OFFSET)}`
    console.log("gasInfo", gasInfo);
    console.log("validUntil", validUntil);
    console.log("validAfter", validAfter);

    const validUntilValidAfter = encodeAbiParameters(
        [{ type: "uint48", name: "validUntil" }, { type: "uint48", name: "validAfter" }],
        [Number(validUntil), Number(validAfter)]
    );
    console.log("validUntilValidAfter", validUntilValidAfter);
    console.log("chainID", chainIDs[chain]);
    console.log("paymaster", paymasters[chain]);

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
            { type: "uint48", name: "validAfter" }
        ],
        [
            getAddress(userOp.sender),
            userOp.nonce,
            pad(keccak256(userOp.initCode), {size: 32}),
            keccak256(userOp.callData),
            // pad(userOp.accountGasLimits, { size: 32 }),
            keccak256(encodedTokenData),
            pad(gasInfo as Hex, { size: 32 }),
            userOp.preVerificationGas,
            pad(userOp.gasFees, { size: 32 }),
            BigInt(chainIDs[chain]),
            getAddress(paymasters[chain]),
            Number(validUntil),
            Number(validAfter)
        ]
    )

    console.log("encodedData", encodedData);
    const userOpHash = keccak256(encodedData);
    console.log("userOpHash", userOpHash);
    return userOpHash;
}

export function getRepayToken(sender: Address) {
    // TODO: check sender locked-funds
    return concat([
        "0x01", // length of the array (only one repay token)
        vaultA["optimism"] as Address,
        pad(numberToHex(500), { size: 32 }),
        pad(numberToHex(chainIDs["optimism"]), { size: 32 })
    ])
}

export function getSponsorTokens(spender: Address, chain: supportedChain) {
    return concat([
        "0x01", // length of the array (only one sponsor token)
        tokenA[chain] as Address,
        spender,
        pad(numberToHex(500), { size: 32 }) // 500 (the NFT Price)
    ])
}