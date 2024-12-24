import { describe, expect, test } from "vitest";
import { getAddress } from "viem";
import { invoiceManager } from "../Invoice";

describe("getInvoiceId", () => {
  test("should match onchain invoice ID computation", async () => {
    const invoice = {
      account: getAddress("0x5E3Ae8798eAdE56c3B4fe8F085DAd16D4912Ba83"),
      paymaster: getAddress("0xF6e64504ed56ec2725CDd0b3C1b23626D66008A2"),
      nonce: 32005827482497451446878209048576n,
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
      "0xccabf5a2f5630bf7e426047c30d25fd0afe4bff9651bc648b4174153a38e38d8";
    const computedInvoiceId = await invoiceManager.getInvoiceId(invoice);
    expect(computedInvoiceId).toBe(expectedInvoiceId);
  });

  /*
    * $ cast call 0xE94b6B5346BF1E46daDDe0002148ec9d3b2778B4 "getInvoiceId(address,address,uint256,uint256,(address,uint256,uint256)[])"
    "0x5E3Ae8798eAdE56c3B4fe8F085DAd16D4912Ba83" "0x19b5CBF65ff1aAEB17e42f701E0AfeEFF0223244" 32005912026784786589178245677056 84532 "[(0x8e2048c85Eae2a4443408C284221B33e61906463, 500, 11155420)]" --rpc-url https://sepolia.base.org
    * ===> 0x155c98d25ec4425c2df7bf064bd434a7d63c86f3b87a948c8ebfbae3e553f21c
    */

  test("should match onchain invoice ID computation", async () => {
    const invoice = {
      account: getAddress("0x5E3Ae8798eAdE56c3B4fe8F085DAd16D4912Ba83"),
      paymaster: getAddress("0x19b5CBF65ff1aAEB17e42f701E0AfeEFF0223244"),
      nonce: 32005912026784786589178245677056n,
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
      "0x155c98d25ec4425c2df7bf064bd434a7d63c86f3b87a948c8ebfbae3e553f21c";
    const computedInvoiceId = await invoiceManager.getInvoiceId(invoice);
    expect(computedInvoiceId).toBe(expectedInvoiceId);
  });
});
