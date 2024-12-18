import {
  createPublicClient,
  createWalletClient,
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
  transport: http(`https://api.pimlico.io/v2/base-sepolia/rpc?apikey=pim_QZqpZqQWSfNVFFhLxMRqDz`),
});


// export const baseSepoliaBundlerClient = createBundlerClient({
//   client: baseSepoliaPublicClient,
//   paymaster: getPaymasterActions("base"),
//   transport: http("http://0.0.0.0:3000`),
// });


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