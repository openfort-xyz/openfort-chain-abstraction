import { z } from "zod";
import { Hex } from "viem";

const jobIdSchema = z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);

const ReceiptRequestProofSchema = z.object({
  jsonrpc: z.literal("2.0"),
  id: z.number(),
  result: jobIdSchema,
});

const ReceiptQueryProofSchema = z.object({
  jsonrpc: z.literal("2.0"),
  id: z.number(),
  result: z.object({
    jobID: jobIdSchema,
    status: z.enum(["complete", "error", "pending"]),
    blockNumber: z.number(),
    receiptIndex: z.number(),
    srcChainId: z.number(),
    dstChainId: z.number(),
    createdAt: z.number(),
    updatedAt: z.number(),
    proof: z.string().optional(),
  }),
});

type ReceiptProofResponse = {
  jobID: number;
  status: "complete" | "error" | "pending";
  blockNumber: number;
  receiptIndex: number;
  srcChainId: number;
  dstChainId: number;
  createdAt: number;
  updatedAt: number;
  proof?: string;
};

class PolymerProverClient {
  constructor(
    private readonly endpoint: string,
    private readonly apiKey: string,
  ) {}

  private async fetchWithValidation<T, O>(
    schema: z.ZodType<T, z.ZodTypeDef, O>,
    body: object,
  ): Promise<T> {
    const response = await fetch(this.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const rawData = (await response.json()) as {
      jsonrpc: string;
      id: number;
      result: unknown;
    };
    return schema.parse(rawData);
  }

  async receiptRequestProof(
    srcChainId: bigint,
    dstChainId: bigint,
    srcBlockNumber: bigint,
    txIndex: bigint,
  ): Promise<number> {
    const response = await this.fetchWithValidation(ReceiptRequestProofSchema, {
      jsonrpc: "2.0",
      id: 1,
      method: "receipt_requestProof",
      params: [
        Number(srcChainId),
        Number(dstChainId),
        Number(srcBlockNumber),
        Number(txIndex),
      ],
    });
    return response.result;
  }

  async queryReceiptProof(jobId: bigint): Promise<ReceiptProofResponse> {
    const response = await this.fetchWithValidation(ReceiptQueryProofSchema, {
      jsonrpc: "2.0",
      id: 1,
      method: "receipt_queryProof",
      params: [Number(jobId)],
    });
    return response.result;
  }
}

export const polymerProverClient = new PolymerProverClient(
  process.env.POLYMER_PROVER_API_ENDPOINT || "secret public endpoint",
  process.env.POLYMER_PROVER_API_KEY || "no token no proof brother",
);
