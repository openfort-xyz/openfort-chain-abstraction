import { z } from "zod";
import { encodeAbiParameters, Hex } from "viem";

const HashiResponseSchema = z.object({
  jsonrpc: z.literal("2.0"),
  id: z.number(),
  result: z.object({
    proof: z.tuple([
      z.number(), // chainId
      z.number(), // blockNumber
      z.string(), // blockHeader
      z.number(), // ancestralBlockNumber
      z.array(z.string()), // ancestralBlockHeaders
      z.array(z.string()), // receiptProof
      z.string(), // transactionIndex
      z.number(), // logIndex
    ]),
  }),
});

type ReceiptProofResponse = {
  chainId: bigint;
  blockNumber: bigint;
  blockHeader: Hex;
  ancestralBlockNumber: bigint;
  ancestralBlockHeaders: Hex[];
  receiptProof: Hex[];
  transactionIndex: Hex;
  logIndex: bigint;
};

class HashiProverClient {
  constructor(
    // NOTE: The Hashi Prover API can run locally.
    // https://github.com/gnosis/hashi/blob/main/packages/rpc/README.md
    // Ecosystems can process refunds without relying on third-party services,
    // including Openfort or any external proof provider.
    private readonly endpoint: string,
  ) {}

  private async fetchWithValidation<T, O>(
    schema: z.ZodType<T, z.ZodTypeDef, O>,
    body: object,
  ): Promise<T> {
    const response = await fetch(this.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const rawData = await response.json();
    return schema.parse(rawData);
  }

  async getReceiptProof(
    chainId: number,
    logIndex: number,
    transactionHash: Hex,
  ): Promise<ReceiptProofResponse> {
    const response = await this.fetchWithValidation(HashiResponseSchema, {
      jsonrpc: "2.0",
      method: "hashi_getReceiptProof",
      params: {
        chainId: Number(chainId),
        logIndex: Number(logIndex),
        transactionHash,
      },
      id: 1,
    });

    const [
      chainId_,
      blockNumber,
      blockHeader,
      ancestralBlockNumber,
      ancestralBlockHeaders,
      receiptProof,
      transactionIndex,
      logIndex_,
    ] = response.result.proof;

    return {
      chainId: BigInt(chainId_),
      blockNumber: BigInt(blockNumber),
      blockHeader: blockHeader as Hex,
      ancestralBlockNumber: BigInt(ancestralBlockNumber),
      ancestralBlockHeaders: ancestralBlockHeaders.map((h) => h as Hex),
      receiptProof: receiptProof.map((p) => p as Hex),
      transactionIndex: transactionIndex as Hex,
      logIndex: BigInt(logIndex_),
    };
  }

  encodeReceiptProof(proof: ReceiptProofResponse): Hex {
    return encodeAbiParameters(
      [
        {
          type: "tuple",
          components: [
            { type: "uint256", name: "chainId" },
            { type: "uint256", name: "blockNumber" },
            { type: "bytes", name: "blockHeader" },
            { type: "uint256", name: "ancestralBlockNumber" },
            { type: "bytes[]", name: "ancestralBlockHeaders" },
            { type: "bytes[]", name: "receiptProof" },
            { type: "bytes", name: "transactionIndex" },
            { type: "uint256", name: "logIndex" },
          ],
        },
      ],
      [proof],
    );
  }
}

export const hashiProverClient = new HashiProverClient(
  process.env.HASHI_PROVER_API_ENDPOINT || "http://127.0.0.1:80/v1",
);
