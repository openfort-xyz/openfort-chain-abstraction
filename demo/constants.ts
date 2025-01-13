import { Address, privateKeyToAccount } from "viem/accounts";
import { baseSepolia, optimismSepolia } from "viem/chains";
// Add proper type definition
export type supportedChain = "optimism" | "base";

export const V7SimpleAccountFactoryAddress =
  "0x91E60e0613810449d098b0b5Ec8b51A0FE8c8985";

export const paymasterVerifier = privateKeyToAccount(
  process.env.PAYMASTER_VERIFIER_PRIVATE_KEY as `0x${string}`,
);
export const ownerAccount = privateKeyToAccount(
  process.env.OWNER_PRIVATE_KEY as `0x${string}`,
);

export type token = Address;

export type Vault = {
  address: Address;
  token: Address;
};

export type OpenfortContracts = {
  paymaster: Address;
  invoiceManager: Address;
  vaultManager: Address;
  vaults: Record<token, Address>;
};

export const openfortContracts: Record<supportedChain, OpenfortContracts> = {
  base: {
    paymaster: "0x9B1D4356014e36d95b0b00251770d641ea02979f",
    invoiceManager: "0xBC11EE7d2F3D74F5A6a5aDD3457908870BFcF37b",
    vaultManager: "0x047F60FE3243d1C54740AD11109f95E9ba927c6D",
    vaults: {
      "0xfF3311cd15aB091B00421B23BcB60df02EFD8db7":
        "0x5502B2Da288Be13F48eE46E3261690Ed4a1e71f9",
      "0xa9a0179e045cF39C5F4d914583dc3648DfBDeeF1":
        "0x0230a6641Fb11e760f2f7A263F6Fe2a9b0476b44",
    },
  },
  optimism: {
    paymaster: "0x511985306FDDE63cda68F5675EC296AAd826b5b8",
    invoiceManager: "0x9dDB3Af574307DFEfE9d69D09A0BBcF55b9e2D34",
    vaultManager: "0xd454fbc6Df5D9d91Fa02e60fD46CDD2208d0b33b",
    vaults: {
      "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A":
        "0xaF45f62eB99AD2091440336ca714B21F06525978",
      "0xd926e338e047aF920F59390fF98A3114CCDcab4a":
        "0x5b306B655B84Bc3201e6f9577d0CDcc7C2e9Ebfb",
    },
  },
};

// TODO: refactor this to only  refer to openfortContracts
export const vaultA = {
  base: "0x5502B2Da288Be13F48eE46E3261690Ed4a1e71f9",
  optimism: "0xaF45f62eB99AD2091440336ca714B21F06525978",
};

export const tokenA = {
  base: "0xfF3311cd15aB091B00421B23BcB60df02EFD8db7",
  optimism: "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A",
};

export const tokenB = {
  base: "0xa9a0179e045cF39C5F4d914583dc3648DfBDeeF1",
  optimism: "0xd926e338e047aF920F59390fF98A3114CCDcab4a",
};

export const demoNFTs = {
  base: "0xD129bda7CE0888d7Fd66ff46e7577c96984d678f",
  optimism: "0x9999999999999999999999999999999999999999",
};

export const chainIDs = {
  base: baseSepolia.id,
  optimism: optimismSepolia.id,
};

export function isValidChain(chain: string): chain is supportedChain {
  return chain === "optimism" || chain === "base";
}
