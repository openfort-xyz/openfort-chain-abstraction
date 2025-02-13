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

// NOTE: cabPaymaster *MUST* have the same address on all chains of the ecosystem
// Its address is included in the invoice on dest chain, which is used for refunds on the source chains
// Use the CABPaymasterFactory to have deterministic addresses for each ecosystem

const cabPaymaster = "0xA6DB931Adc6636e14bC95F5a9f33B3DB6c4aFF96";
const cabPaymasterVerifier = "0x00a3E1CaCFb2b2a2CA64Ee8bA9D9a2231D7ccFa9";
const invoiceManager = "0x6C739d3A4dA696D730dBAd2c2B8ca6668D415d91";

export const openfortContracts: Record<supportedChain, OpenfortContracts> = {
  base: {
    adminPaymaster: "0x9964Cf8cDfeCdFc3DA38731FdB1a5Ec343BDe25b",
    cabPaymaster: cabPaymaster,
    paymasterVerifier: cabPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0x5f8B5EF192e60D7c01D6F4c1c31dC191EE0E2063",
    vaults: {
      "0xfF3311cd15aB091B00421B23BcB60df02EFD8db7":
        "0x3871Ab9265B096a18fa682982B9E058324F3Af60",
      "0xa9a0179e045cF39C5F4d914583dc3648DfBDeeF1":
        "0x2E5152910b6b8f4aFED6193843C5AD1eD731adc5",
    },
  },
  optimism: {
    adminPaymaster: "0xF9Bc9D52b9686DD2D553332a86D1c39BE16f5AF9",
    cabPaymaster: cabPaymaster,
    paymasterVerifier: cabPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0x9b93C1a32E78edaBC078911505B7666Df9DF3bB7",
    vaults: {
      "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A":
        "0x593a9fa6Cd8077FE806e23834a5C59a78CAb5719",
      "0xd926e338e047aF920F59390fF98A3114CCDcab4a":
        "0xf36f0F59Bc79de809cEf3E3B86BD4759Fc1e0C55",
    },
  },
  mantle: {
    adminPaymaster: "0xabB466C0a5A7ac86EbEC00B413cd35c85f6544AF",
    cabPaymaster: cabPaymaster,
    paymasterVerifier: cabPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0xE295199e935925658A97F5f0cAb5fE069305ea57",
    vaults: {
      "0x4855090BbFf14397E1d48C9f4Cd7F111618F071a":
        "0x28E768F281C2Bc46889EE412e86Bb4CA1ed054CD",
      "0x76501186fB44d508b9aeC50899037F33C6FF4A36":
        "0xf7E531f59809134a010E43c3A83B3f1E4015E41d",
    },
  },
};

// TODO: refactor this to only  refer to openfortContracts
export const vaultA = {
  base: "0x3871Ab9265B096a18fa682982B9E058324F3Af60",
  optimism: "0x593a9fa6Cd8077FE806e23834a5C59a78CAb5719",
  mantle: "0x28E768F281C2Bc46889EE412e86Bb4CA1ed054CD",
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
