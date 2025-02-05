import { Address, privateKeyToAccount } from "viem/accounts";
import { baseSepolia, optimismSepolia, mantleSepoliaTestnet } from "viem/chains";
// Add proper type definition
export type supportedChain = "optimism" | "base" | "mantle";

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
    paymaster: "0x4036469C65800b6A2278BB9603c3Aae8e22e046d",
    invoiceManager: "0xf81173107aA5c72042d3F6676AD61aE08242d364",
    vaultManager: "0x56818692A9d313Bf39Ac095E5670Ebd66B98F6EA",
    vaults: {
      "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A":
        "0xFE84D9E1B3A2AbAB1EB53A9D50E58B6D7FFe268C",
      "0xd926e338e047aF920F59390fF98A3114CCDcab4a":
        "0x3f4c40dE7702FcDF93d4DF9bdbBe8c34F107a21a",
    },
  },
  mantle: {
    paymaster: "0xeDb665E8e20f95bA4d79a8C208aeFF21f05dC88B",
    invoiceManager: "0x4501B873f3DA90a79B4F898E2627B88b63F37039",
    vaultManager: "0x8BFf6f29A6435C35a29dCE67baEa050160A9e41e",
    vaults: {
      "0x4855090BbFf14397E1d48C9f4Cd7F111618F071a":
        "0x30C788123bF7540828CEc9dA861Eca4009DECef8",
      "0x76501186fB44d508b9aeC50899037F33C6FF4A36":
        "0x537758a6b09D042B12b7C0Cb18CEc466E83640E1",
    },
  },
};

// TODO: refactor this to only  refer to openfortContracts
export const vaultA = {
  base: "0x5502B2Da288Be13F48eE46E3261690Ed4a1e71f9",
  optimism: "0xaF45f62eB99AD2091440336ca714B21F06525978",
  mantle: "0x30C788123bF7540828CEc9dA861Eca4009DECef8",
};

export const tokenA = {
  base: "0xfF3311cd15aB091B00421B23BcB60df02EFD8db7",
  optimism: "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A",
  mantle: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", // Sponsor with native token on Mantle
};

export const tokenB = {
  base: "0xa9a0179e045cF39C5F4d914583dc3648DfBDeeF1",
  optimism: "0xd926e338e047aF920F59390fF98A3114CCDcab4a",
  mantle: "0x76501186fB44d508b9aeC50899037F33C6FF4A36",
};

export const demoNFTs = {
  base: "0xD129bda7CE0888d7Fd66ff46e7577c96984d678f",
  optimism: "0x9999999999999999999999999999999999999999",
  mantle: "0x824a4c49a1306F0a5e2e05c8e93510442363893e", // DEMO: DemoNativeNFT on Mantle
};

export const chainIDs = {
  base: baseSepolia.id,
  optimism: optimismSepolia.id,
  mantle: mantleSepoliaTestnet.id,
};

export function isValidChain(chain: string): chain is supportedChain {
  return chain === "optimism" || chain === "base" || chain === "mantle";
}
