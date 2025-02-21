import {
  createPublicClient,
  createWalletClient,
  http,
  PublicClient,
  WalletClient,
} from "viem";
import { BundlerClient, createBundlerClient } from "viem/account-abstraction";
import {
  baseSepolia,
  mantleSepoliaTestnet,
  optimismSepolia,
  polygonAmoy,
} from "viem/chains";
import { ownerAccount, supportedChain } from "./constants";
import { getPaymasterActions } from "./paymaster";

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

const polygonPublicClient = createPublicClient({
  chain: polygonAmoy,
  transport: http(),
});

export const publicClients: Record<supportedChain, PublicClient> = {
  optimism: optimismPublicClient as PublicClient,
  base: baseSepoliaPublicClient as PublicClient,
  mantle: mantleSepoliaPublicClient as PublicClient,
  polygon: polygonPublicClient as PublicClient,
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

const polygonWalletClient = createWalletClient({
  account: ownerAccount,
  chain: polygonAmoy,
  transport: http(),
});

export const walletClients: Record<supportedChain, WalletClient> = {
  optimism: optimismWalletClient,
  base: baseSepoliaWalletClient,
  mantle: mantleSepoliaWalletClient,
  polygon: polygonWalletClient,
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

const mantleSepoliaBundlerClient = createBundlerClient({
  client: mantleSepoliaPublicClient,
  paymaster: getPaymasterActions("mantle"),

  transport: http(
    `https://api.pimlico.io/v2/mantle-sepolia/rpc?apikey=${process.env.PIMLICO_API_KEY}`,
  ),
});

const polygonBundlerClient = createBundlerClient({
  client: polygonPublicClient,
  paymaster: getPaymasterActions("polygon"),
  transport: http(
    `https://api.pimlico.io/v2/polygon-amoy/rpc?apikey=${process.env.PIMLICO_API_KEY}`,
  ),
});

export const bundlerClients: Record<supportedChain, BundlerClient> = {
  optimism: optimismBundlerClient as BundlerClient,
  base: baseSepoliaBundlerClient as BundlerClient,
  mantle: mantleSepoliaBundlerClient as BundlerClient,
  polygon: polygonBundlerClient as BundlerClient,
};
