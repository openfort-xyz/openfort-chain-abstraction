import {
  createPublicClient,
  createWalletClient,
  http,
  PublicClient,
  WalletClient,
} from "viem";
import { createBundlerClient } from "viem/account-abstraction";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia, optimism, optimismSepolia } from "viem/chains";
import { supportedChain } from "./constants";

const ownerAccount = privateKeyToAccount(
  process.env.OWNER_PRIVATE_KEY as `0x${string}`,
);

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

export const baseSepoliaBundlerClient = createBundlerClient({
  client: baseSepoliaPublicClient,
  transport: http("http://localhost:4337"),
});

export const optimismBundlerClient = createBundlerClient({
  client: optimismPublicClient,
  transport: http("http://localhost:4337"),
});

export const walletClients: Record<supportedChain, WalletClient> = {
  optimism: optimismWalletClient,
  base: baseSepoliaWalletClient,
};

export const publicClients: Record<supportedChain, PublicClient> = {
  optimism: optimismPublicClient as PublicClient,
  base: baseSepoliaPublicClient as PublicClient,
};
