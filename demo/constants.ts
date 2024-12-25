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
    paymaster: "0x3cB057Fd3BE519cB50788b8b282732edBF533DC6",
    invoiceManager: "0x666eB01fBba3F3D5f7e5d8e72c6Ea57B6AF09798",
    vaultManager: "0xEA7aa047c78c5583a2896e18E127A5C2E59C0887",
    vaults: {
      "0xfF3311cd15aB091B00421B23BcB60df02EFD8db7":
        "0x21c14066F5D62Cbec3c42e2c718Ce82E72fCBF87",
      "0xa9a0179e045cF39C5F4d914583dc3648DfBDeeF1":
        "0x742d0fc742B89267411c5AC24a5fdA3CA264eeC2",
    },
  },
  optimism: {
    paymaster: "0x48c2DE32E983cD077486c218a2f6A0119E1446cF",
    invoiceManager: "0x2C4511a143e9C583B5Ae5c4206A4C9D3882F35Bf",
    vaultManager: "0x1EEb54d847BC170a4F1e12312f9b5D74EeCF1018",
    vaults: {
      "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A":
        "0xeFb7144787FFFCEF306bC99cEBF42AB08d5609c8",
      "0xd926e338e047aF920F59390fF98A3114CCDcab4a":
        "0x34BC35Ff16C1ab0e5123D5De58eC8d1353B09968",
    },
  },
};

// TODO: refactor this to only  refer to openfortContracts
export const vaultA = {
  base: "0x21c14066F5D62Cbec3c42e2c718Ce82E72fCBF87",
  optimism: "0xeFb7144787FFFCEF306bC99cEBF42AB08d5609c8",
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
