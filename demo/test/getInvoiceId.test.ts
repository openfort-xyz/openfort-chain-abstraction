import { describe, expect, test } from "vitest";
import { getAddress } from "viem";
import { invoiceManager } from "../Invoice";

describe("getInvoiceId", () => {
  /*
   * cast call 0xec721B31c1F003E3D45671D3e6cB83F73AA8f0D6 "getInvoiceId(address,address,uint256,uint256,bytes)" "0x499E26E7A97cB8F89bE5668770Fb022fdDbCa40d" "0x76342B873f9583f9a1D2cF7b12F0b3E0536E1a71" 32006121834480964251358041473024 84532 "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000008e2048c85eae2a4443408c284221b33e6190646300000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000aa37dc" --rpc-url https://sepolia.base.org
   * ===> 0xc7fea7a3bdb81a75efca8bda6e2082245bc07b38bf7827aa8b8e0e7036987909
   */

  test("should match onchain invoice ID computation", async () => {
    const invoice = {
      account: getAddress("0x499E26E7A97cB8F89bE5668770Fb022fdDbCa40d"),
      paymaster: getAddress("0x3B03425198341CD6469Ba3e05e215a458CF021E6"),
      nonce: 32006186547098020862214455427072n,
      sponsorChainId: 84532n,
      repayTokenInfos: [
        {
          vault: getAddress("0x8e2048c85Eae2a4443408C284221B33e61906463"),
          amount: 500n,
          chainId: 11155420n,
        },
      ],
    };

    const expectedInvoiceId =
      "0x8d1d56f301140f5e317ae961e5eb8065d04f7ef60725e4305b88f757245d2212";
    const computedInvoiceId = await invoiceManager.getInvoiceId(invoice);
    expect(computedInvoiceId).toBe(expectedInvoiceId);
  });
});
