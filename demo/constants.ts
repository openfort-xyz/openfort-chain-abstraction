import { Address, privateKeyToAccount } from "viem/accounts";
import {
  baseSepolia,
  optimismSepolia,
  mantleSepoliaTestnet,
} from "viem/chains";
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
  adminPaymaster: Address; // Demo only paymaster for admin operation such as registerting the CABPaymaster
  cabPaymaster: Address; // The real chain abstracted paymaster
  paymasterVerifier: Address; // Handles Polymer proof verfication
  invoiceManager: Address; // The invoice manager contract
  vaultManager: Address; // The vault manager contract
  vaults: Record<token, Address>; // The vaults for each token
};

export const openfortContracts: Record<supportedChain, OpenfortContracts> = {
  base: {
    adminPaymaster: "0x9964Cf8cDfeCdFc3DA38731FdB1a5Ec343BDe25b",
    cabPaymaster: "0xbbeF4b5266169A711b1819bC0Ab10112cA4D24bB",
    paymasterVerifier: "0xd5310f1C2d3A7eCd96283B30874Af26648Eeb4eE",
    invoiceManager: "0xBC11EE7d2F3D74F5A6a5aDD3457908870BFcF37b",
    vaultManager: "0xc3767cCed71c41a66802b25a8a667Aee1DbE2826",
    vaults: {
      "0xfF3311cd15aB091B00421B23BcB60df02EFD8db7":
        "0x258840B7e74e4660089140A8104ABa9bd67C0E9b",
      "0xa9a0179e045cF39C5F4d914583dc3648DfBDeeF1":
        "0xa0c64E640573C405B77637203abC2A9661008674",
    },
  },
  optimism: {
    adminPaymaster: "0xF9Bc9D52b9686DD2D553332a86D1c39BE16f5AF9",
    cabPaymaster: "0x4036469C65800b6A2278BB9603c3Aae8e22e046d",
    paymasterVerifier: "0x0c02E01B0884B50b89EeF05AFDe65334B82aA274",
    invoiceManager: "0x172E376da80575c2aD3A68854F7fB6083f134e1E",
    vaultManager: "0xaf57C2e05E7aE190E4Feb989d92D3008E593cADe",
    vaults: {
      "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A":
        "0x1c5E9D330BFc00890841D7797e03Df73aab84053",
      "0xd926e338e047aF920F59390fF98A3114CCDcab4a":
        "0xd8dCfc1c65336D542EF857A453C4046eaaE109e4",
    },
  },
  mantle: {
    adminPaymaster: "0x6371FB8d4e1151913BF946d6843501Faf56Ab833",
    cabPaymaster: "0x6371FB8d4e1151913BF946d6843501Faf56Ab833",
    paymasterVerifier: "0x34Fb7d3CC87697f54B5BA5d75dD3aa9983544f46",
    invoiceManager: "0x00C9568D0A7E4eCB9C2085AAa5C8F8B13503cc06",
    vaultManager: "0xE869AF36EDAa4c7CbCa1632872927629be681BfE",
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
