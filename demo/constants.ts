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

// NOTE: Salt 0x0603202500000000000000000000000000000000000000000000000000000000
const cabPaymaster = "0xE45BC02340CA4197cfC9578e5BBa3B80b4e4C2d4";
const polymerPaymasterVerifier = "0x230156A2282CA96f1234a387561E4cE13912F5eC";
const hashiPaymasterVerifier = "0x40E8340A47CFF4E98bB209586C73239064961550";
const invoiceManager = "0x9dCe39E65DD581195bf721F96026F0bC31e32De9";

export const openfortContracts: Record<string, OpenfortContracts> = {
  base: {
    adminPaymaster: "0x9964Cf8cDfeCdFc3DA38731FdB1a5Ec343BDe25b",
    cabPaymaster: cabPaymaster,
    polymerPaymasterVerifier: polymerPaymasterVerifier,
    hashiPaymasterVerifier: hashiPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0x62524025da23977CF05FB6a541d5307468Cc7265",
    vaults: {
      "0xfF3311cd15aB091B00421B23BcB60df02EFD8db7":
        "0x591686fF602f793474ecCe78eb9C404Caf35A8B1",
      "0xa9a0179e045cF39C5F4d914583dc3648DfBDeeF1":
        "0xAcbC844958247469bEAe27Df0fe0cf34F1e2bFFD",
    },
  },
  optimism: {
    adminPaymaster: "0xF9Bc9D52b9686DD2D553332a86D1c39BE16f5AF9",
    cabPaymaster: cabPaymaster,
    polymerPaymasterVerifier: polymerPaymasterVerifier,
    hashiPaymasterVerifier: hashiPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0xf864A6A98646a7A91e6dC1731309DD4638AaB290",
    vaults: {
      "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A":
        "0x18413032138DE0E4ef6A0643eCb1DcE514fc0365",
      "0xd926e338e047aF920F59390fF98A3114CCDcab4a":
        "0x49b94c5ceFF0ab7d632eDf8Fcd778F362602A92b",
    },
  },
  mantle: {
    adminPaymaster: "0xabB466C0a5A7ac86EbEC00B413cd35c85f6544AF",
    cabPaymaster: cabPaymaster,
    polymerPaymasterVerifier: polymerPaymasterVerifier,
    hashiPaymasterVerifier: hashiPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0xB19f2fbB613Dc6d43A04f5326baE90DF653A0DEa",
    vaults: {
      "0x4855090BbFf14397E1d48C9f4Cd7F111618F071a":
        "0xB653C9a30c3b7eeC243f0FC07317CE95F985aF7E",
      "0x76501186fB44d508b9aeC50899037F33C6FF4A36":
        "0x410e21c8aA84f889d99dA54f01F0108c5de61D21",
    },
  },
  polygon: {
    adminPaymaster: "0x3b0fdE0dFa4EC9AE1dA86f889B7eA6C9628615e9",
    cabPaymaster: cabPaymaster,
    polymerPaymasterVerifier: polymerPaymasterVerifier,
    hashiPaymasterVerifier: hashiPaymasterVerifier,
    invoiceManager: invoiceManager,
    vaultManager: "0x0e2264b62a5b2B54B32E310351E1740dB8e6f1DE",
    vaults: {
      "0x8d59703E60051792396Da5C495215B25748d291f":
        "0xB2145d6328658Cc87fCb3B925b4Fa19B8703875a",
      "0xEd01Aa1e63abdB90e5eA3a66c720483a318c4749":
        "0xE45BC02340CA4197cfC9578e5BBa3B80b4e4C2d4",
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
