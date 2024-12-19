import {
  createPublicClient,
  createWalletClient,
  Hex,
  http,
  PublicClient,
  WalletClient,
} from "viem";
import { BundlerClient, createBundlerClient } from "viem/account-abstraction";
import { baseSepolia, optimismSepolia } from "viem/chains";
import { ownerAccount, supportedChain } from "./constants";
import { getPaymasterActions } from "./paymaster";

export const optimismPublicClient = createPublicClient({
  chain: optimismSepolia,
  transport: http(),
});

export const baseSepoliaPublicClient = createPublicClient({
  chain: baseSepolia,
  transport: http(),
});


export const baseSepoliaWalletClient = createWalletClient({
  account: ownerAccount,
  chain: baseSepolia,
  transport: http(),
});

export const optimismWalletClient = createWalletClient({
  account: ownerAccount,
  chain: optimismSepolia,
  transport: http(),
});

// export const baseSepoliaBundlerClient = createBundlerClient({
//   client: baseSepoliaPublicClient,
//   paymaster: getPaymasterActions("base"),
//   transport: http(`http://localhost:8080/bundler/${baseSepolia.id}`),
// });

export const baseSepoliaBundlerClient = createBundlerClient({
  client: baseSepoliaPublicClient,
  paymaster: getPaymasterActions("base"),
  transport: http(
    `https://api.pimlico.io/v2/base-sepolia/rpc?apikey=${process.env.PIMLICO_API_KEY}`
  ),
});


// export const baseSepoliaBundlerClient = createBundlerClient({
//   client: baseSepoliaPublicClient,
//   paymaster: getPaymasterActions("base"),
//   transport: http("http://0.0.0.0:3000")



export const optimismBundlerClient = createBundlerClient({
  client: optimismPublicClient,
  paymaster: getPaymasterActions("optimism"),
  transport: http(`http://localhost:8080/bundler/${optimismSepolia.id}`),
});

export const walletClients: Record<supportedChain, WalletClient> = {
  optimism: optimismWalletClient,
  base: baseSepoliaWalletClient,
};

export const publicClients: Record<supportedChain, PublicClient> = {
  optimism: optimismPublicClient as PublicClient,
  base: baseSepoliaPublicClient as PublicClient,
};

export const bundlerClients: Record<supportedChain, BundlerClient> = {
  optimism: optimismBundlerClient as BundlerClient,
  base: baseSepoliaBundlerClient as BundlerClient,
};



export class PolymerProverClient {
  constructor(private readonly endpoint: string, private readonly apiKey: string) {
    this.apiKey = apiKey;
    this.endpoint = endpoint;
  }

  async getUserOpExecutionProof(userOpHash: Hex) {
    const response = await fetch(`${this.endpoint}`, {
      method: "POST",
      body: JSON.stringify({ jsonrpc: "2.0", method: "eth_getProof", params: [userOpHash, ["nonce", "balance", "code", "codeHash", "nonce", "balance", "code", "codeHash", "nonce", "balance", "code", "codeHash"]] }),
    });
  }
}