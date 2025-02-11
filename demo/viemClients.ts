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
import { mantleSepoliaTestnet } from "viem/chains";

// ============================= PUBLIC CLIENTS =============================

const mantleSepoliaPublicClient = createPublicClient({
  chain: mantleSepoliaTestnet,
  transport: http(),
});

const optimismPublicClient = createPublicClient({
  chain: optimismSepolia,
  transport: http(),
});

const baseSepoliaPublicClient = createPublicClient({
  chain: baseSepolia,
  transport: http(),
});

export const publicClients: Record<supportedChain, PublicClient> = {
  optimism: optimismPublicClient as PublicClient,
  base: baseSepoliaPublicClient as PublicClient,
  mantle: mantleSepoliaPublicClient as PublicClient,
};

// ============================= WALLET CLIENTS =============================

const optimismWalletClient = createWalletClient({
  account: ownerAccount,
  chain: optimismSepolia,
  transport: http(),
});

const baseSepoliaWalletClient = createWalletClient({
  account: ownerAccount,
  chain: baseSepolia,
  transport: http(),
});

const mantleSepoliaWalletClient = createWalletClient({
  account: ownerAccount,
  chain: mantleSepoliaTestnet,
  transport: http(),
});

export const walletClients: Record<supportedChain, WalletClient> = {
  optimism: optimismWalletClient,
  base: baseSepoliaWalletClient,
  mantle: mantleSepoliaWalletClient,
};

// ============================= BUNDLER CLIENTS =============================

const baseSepoliaBundlerClient = createBundlerClient({
  client: baseSepoliaPublicClient,
  paymaster: getPaymasterActions("base"),
  transport: http(
    `https://api.pimlico.io/v2/base-sepolia/rpc?apikey=${process.env.PIMLICO_API_KEY}`,
  ),
});

const optimismBundlerClient = createBundlerClient({
  client: optimismPublicClient,
  paymaster: getPaymasterActions("optimism"),
  transport: http(
    `https://api.pimlico.io/v2/optimism-sepolia/rpc?apikey=${process.env.PIMLICO_API_KEY}`,
  ),
});

// NOTE: running local bundler for mantle sepolia demo because pimlico doesn't support it yet
const mantleSepoliaBundlerClient = createBundlerClient({
  client: mantleSepoliaPublicClient,
  paymaster: getPaymasterActions("mantle"),
  transport: http("http://127.0.0.1:4337"),
});

export const bundlerClients: Record<supportedChain, BundlerClient> = {
  optimism: optimismBundlerClient as BundlerClient,
  base: baseSepoliaBundlerClient as BundlerClient,
  mantle: mantleSepoliaBundlerClient as BundlerClient,
};
