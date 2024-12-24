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
    paymaster: "0x892c3b4C86803EbfAfBECcE9220F3F49d801Fd8A",
    invoiceManager: "0xa3152B80759dfb0cB74009F4bB31b29d01e0e624",
    vaultManager: "0x9E6A6E55D9DbE20DF20A90C426724442C8D95481",
    vaults: {
      "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A":
        "0x8e2048c85Eae2a4443408C284221B33e61906463",
      "0xd926e338e047aF920F59390fF98A3114CCDcab4a":
        "0xB35E1f4A65341e6D916902AB0238AC17c59b7430",
    },
  },
};

export const paymasters = {
  base: "0x3cB057Fd3BE519cB50788b8b282732edBF533DC6",
  optimism: "0x7926E12044F7f29150F5250B1A335a145298308d",
};

export const vaultManagers = {
  base: "0xEA7aa047c78c5583a2896e18E127A5C2E59C0887",
  optimism: "0x9E6A6E55D9DbE20DF20A90C426724442C8D95481",
};

export const invoiceManagers = {
  base: "0xec721B31c1F003E3D45671D3e6cB83F73AA8f0D6",
  optimism: "0xa3152B80759dfb0cB74009F4bB31b29d01e0e624",
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

export const vaultA = {
  base: "0x21c14066F5D62Cbec3c42e2c718Ce82E72fCBF87",
  optimism: "0x8e2048c85Eae2a4443408C284221B33e61906463",
};

export const chainIDs = {
  base: baseSepolia.id,
  optimism: optimismSepolia.id,
};

export function isValidChain(chain: string): chain is supportedChain {
  return chain === "optimism" || chain === "base";
}
