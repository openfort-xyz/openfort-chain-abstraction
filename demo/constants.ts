import { Address, privateKeyToAccount } from "viem/accounts";
import {
  baseSepolia,
  optimismSepolia,
  mantleSepoliaTestnet,
  polygonAmoy,
} from "viem/chains";

// https://ethereum-magicians.org/t/eip-7528-eth-native-asset-address-convention/15989
const NATIVE_TOKEN = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

export const V7SimpleAccountFactoryAddress =
  "0x91E60e0613810449d098b0b5Ec8b51A0FE8c8985";

export const paymasterVerifierAccount = privateKeyToAccount(
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
  adminPaymaster: Address;
  cabPaymaster: Address;
  polymerPaymasterVerifier: Address;
  hashiPaymasterVerifier: Address;
  invoiceManager: Address;
  vaultManager: Address;
  vaults: Record<token, Address>;
};

// NOTE: cabPaymaster *MUST* have the same address on all chains of the ecosystem
// Its address is included in the invoice on dest chain, which is used for refunds on the source chains
// Use the CABPaymasterFactory to have deterministic addresses for each ecosystem

// NOTE: Salt 0x907 - only deployed on base and polygon to demo Hashi Prover
const cabPaymaster = "0x0A68C0766D16aF76bAB3226BB3c46bce3478DF99";
const polymerPaymasterVerifier = "0xF624A9Ad22D7428ADb35CE790340f43C6fE5f2A2";
const hashiPaymasterVerifier = "0xcAeAb7F95D9a42b5DF2fA83e3232efcF65Db5444";
const invoiceManager = "0x9285C1a617131Ca435db022110971De9255Edd9D";

export const openfortContracts: Record<string, OpenfortContracts> = {
  base: {
    adminPaymaster: "0x9964Cf8cDfeCdFc3DA38731FdB1a5Ec343BDe25b",
    cabPaymaster: cabPaymaster,
    polymerPaymasterVerifier: polymerPaymasterVerifier,
    hashiPaymasterVerifier: hashiPaymasterVerifier,
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
    polymerPaymasterVerifier: polymerPaymasterVerifier,
    hashiPaymasterVerifier: hashiPaymasterVerifier,
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
    polymerPaymasterVerifier: polymerPaymasterVerifier,
    hashiPaymasterVerifier: hashiPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0xE295199e935925658A97F5f0cAb5fE069305ea57",
    vaults: {
      "0x4855090BbFf14397E1d48C9f4Cd7F111618F071a":
        "0x28E768F281C2Bc46889EE412e86Bb4CA1ed054CD",
      "0x76501186fB44d508b9aeC50899037F33C6FF4A36":
        "0xf7E531f59809134a010E43c3A83B3f1E4015E41d",
    },
  },
  polygon: {
    adminPaymaster: "0x3b0fdE0dFa4EC9AE1dA86f889B7eA6C9628615e9",
    cabPaymaster: cabPaymaster,
    polymerPaymasterVerifier: polymerPaymasterVerifier,
    hashiPaymasterVerifier: hashiPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0x3833b47F09262279576534d764C1B1974C5AaA40",
    vaults: {
      "0x8d59703E60051792396Da5C495215B25748d291f":
        "0x7C1186b3831ce768E93047402EA06FD31b6f0e4B",
      "0xEd01Aa1e63abdB90e5eA3a66c720483a318c4749":
        "0x2010F3751bBFF6Bbd28C085481F32eAf6FF73B7e",
    },
  },
};

// Add proper type definition
export type supportedChain = keyof typeof openfortContracts;

// TODO: refactor this to only refer to openfortContracts
export const vaultA: Record<supportedChain, Address> = {
  base: "0x3871Ab9265B096a18fa682982B9E058324F3Af60",
  optimism: "0x593a9fa6Cd8077FE806e23834a5C59a78CAb5719",
  mantle: "0x28E768F281C2Bc46889EE412e86Bb4CA1ed054CD",
  polygon: "0x7C1186b3831ce768E93047402EA06FD31b6f0e4B",
};

export const tokenA: Record<supportedChain, Address> = {
  base: "0xfF3311cd15aB091B00421B23BcB60df02EFD8db7",
  optimism: "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A",
  mantle: NATIVE_TOKEN,
  polygon: "0x8d59703E60051792396Da5C495215B25748d291f",
};

// NOTE: demo getting refund on optimism and polygon
// for fronted funds on base and mantle
export const demoNFTs: Record<supportedChain, Address> = {
  base: "0xD129bda7CE0888d7Fd66ff46e7577c96984d678f",
  optimism: "0x9999999999999999999999999999999999999999",
  mantle: "0x824a4c49a1306F0a5e2e05c8e93510442363893e",
  polygon: "0x9999999999999999999999999999999999999999",
};

export const chainIDs: Record<supportedChain, number> = {
  base: baseSepolia.id,
  optimism: optimismSepolia.id,
  mantle: mantleSepoliaTestnet.id,
  polygon: polygonAmoy.id,
};

// yess ... typescript is just a js linter
export function isValidChain(chain: string): chain is supportedChain {
  return ["base", "optimism", "mantle", "polygon"].includes(chain);
}
