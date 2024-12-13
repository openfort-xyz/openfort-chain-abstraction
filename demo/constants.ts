// Add proper type definition
export type supportedChain = "optimism" | "base";

export const openfortAccountFactory =
  "0xCB71E008B9062bb7aBd558816f8135Ef2caB576F";
export const owner = "0x9590Ed0C18190a310f4e93CAccc4CC17270bED40";

export const paymasters = {
  base: "0xA1D5C22d20C41998026e32dEE0eaF9cbC56f7d6E",
  optimism: "0x7926E12044F7f29150F5250B1A335a145298308d",
};

export const vaultManagers = {
  base: "0x38c3c2d2BDdDBC2916d9c85638932f8Fd2F4a7fe",
  optimism: "0x9E6A6E55D9DbE20DF20A90C426724442C8D95481",
};

export const invoiceManagers = {
  base: "0xE94b6B5346BF1E46daDDe0002148ec9d3b2778B4",
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

export function isValidChain(chain: string): chain is supportedChain {
  return chain === "optimism" || chain === "base";
}
