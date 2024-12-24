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
    paymaster: "0x7A4d8f9321fEbC571CE3233668D87aC647D446D1",
    invoiceManager: "0x28FCF5Ebe34e6e1bC236Ed185E6b1f2C481b7D5E",
    vaultManager: "0x5C068c5a73B9A92072738DF70Cd100763d167D03",
    vaults: {
      "0x2522F4Fc9aF2E1954a3D13f7a5B2683A00a4543A":
        "0x2e13e2daD7e324904580E39F931E2821a29fee15",
      "0xd926e338e047aF920F59390fF98A3114CCDcab4a":
        "0x12EEC47E20a4d3d9A46A9aDeDA08561B423f3C69",
    },
  },
};

export const paymasters = {
  base: "0x3cB057Fd3BE519cB50788b8b282732edBF533DC6",
  optimism: "0x7A4d8f9321fEbC571CE3233668D87aC647D446D1",
};

export const vaultManagers = {
  base: "0xEA7aa047c78c5583a2896e18E127A5C2E59C0887",
  optimism: "0x5C068c5a73B9A92072738DF70Cd100763d167D03",
};

export const invoiceManagers = {
  base: "0xec721B31c1F003E3D45671D3e6cB83F73AA8f0D6",
  optimism: "0x28FCF5Ebe34e6e1bC236Ed185E6b1f2C481b7D5E",
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
  optimism: "0x2e13e2daD7e324904580E39F931E2821a29fee15",
};

export const chainIDs = {
  base: baseSepolia.id,
  optimism: optimismSepolia.id,
};

export function isValidChain(chain: string): chain is supportedChain {
  return chain === "optimism" || chain === "base";
}
