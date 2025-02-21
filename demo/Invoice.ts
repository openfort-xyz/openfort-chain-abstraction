import { z } from "zod";
import {
  encodeAbiParameters,
  encodePacked,
  getAddress,
  Hex,
  keccak256,
} from "viem";
import fs from "fs/promises";
import path from "path";
import { getRepayTokens } from "./utils";

const RepayTokenInfoSchema = z.object({
  vault: z
    .string()
    .regex(/^0x[a-fA-F0-9]{40}$/)
    .transform((val) => getAddress(val)),
  amount: z.string().transform((val) => BigInt(val)),
  chainId: z.string().transform((val) => BigInt(val)),
});

const InvoiceWithRepayTokensSchema = z.object({
  account: z
    .string()
    .regex(/^0x[a-fA-F0-9]{40}$/)
    .transform((val) => getAddress(val)),
  paymaster: z
    .string()
    .regex(/^0x[a-fA-F0-9]{40}$/)
    .transform((val) => getAddress(val)),
  nonce: z.string().transform((val) => BigInt(val)),
  sponsorChainId: z.string().transform((val) => BigInt(val)),
  repayTokenInfos: z.array(RepayTokenInfoSchema),
});

const InvoiceIdSchema = z
  .string()
  .regex(/^0x[a-fA-F0-9]{64}$/, "Must be a 32-byte hex string");

const InvoicesSchema = z.record(InvoiceIdSchema, InvoiceWithRepayTokensSchema);

export type InvoiceId = z.infer<typeof InvoiceIdSchema>;
export type InvoiceWithRepayTokens = z.infer<
  typeof InvoiceWithRepayTokensSchema
>;
export type Invoices = z.infer<typeof InvoicesSchema>;

export interface InvoiceIO {
  readInvoice(invoiceId: InvoiceId): Promise<InvoiceWithRepayTokens>;
  writeInvoice(invoice: InvoiceWithRepayTokens): Promise<InvoiceId>;
}

/**
 * InvoiceManager reads and writes invoices to a JSON file.
 * FOR DEMO PURPOSES ONLY - implement InvoiceIO to use a database in production.
 */

class InvoiceManager implements InvoiceIO {
  private invoicesPath: string;

  constructor(invoicesPath: string) {
    this.invoicesPath = invoicesPath;
  }

  async readInvoice(invoiceId: InvoiceId): Promise<InvoiceWithRepayTokens> {
    const invoices = await this.readInvoices();
    const invoice = invoices[invoiceId];
    if (!invoice) {
      throw new Error(`Invoice ID ${invoiceId} not found`);
    }
    return invoice;
  }

  async writeInvoice(invoice: InvoiceWithRepayTokens): Promise<InvoiceId> {
    try {
      const invoices = await this.readInvoices();
      const invoiceId = this.getInvoiceId(invoice);
      invoices[invoiceId] = invoice;
      const serializedInvoices = JSON.stringify(
        invoices,
        (key, value) => (typeof value === "bigint" ? value.toString() : value),
        2,
      );
      await fs.writeFile(this.invoicesPath, serializedInvoices);
      return invoiceId;
    } catch (error: any) {
      console.error("Error handling invoices:", error.message);
      throw new Error("Failed to write the invoice.");
    }
  }

  getInvoiceId(invoice: InvoiceWithRepayTokens): InvoiceId {
    // NOTE: hardcoded polygon for demo purposes
    const repayTokensEncoded = getRepayTokens(invoice.account, "polygon");
    const packed = encodePacked(
      ["address", "address", "uint256", "uint256", "bytes"],
      [
        invoice.account,
        invoice.paymaster,
        invoice.nonce,
        invoice.sponsorChainId,
        repayTokensEncoded,
      ],
    );
    return keccak256(packed) as InvoiceId;
  }

  private async readInvoices(): Promise<Invoices> {
    try {
      const fileContent = await fs.readFile(this.invoicesPath, "utf8");
      const invoicesJson = fileContent ? JSON.parse(fileContent) : {};
      return InvoicesSchema.parse(invoicesJson);
    } catch (err: any) {
      if (err.code === "ENOENT") {
        throw new Error(`File not found at path: ${this.invoicesPath}`);
      } else if (err.name === "SyntaxError") {
        throw new Error(`Invalid JSON format in file: ${this.invoicesPath}`);
      } else if (err instanceof z.ZodError) {
        throw new Error(`Validation error: ${err.message}`);
      } else {
        throw new Error(`An unexpected error occurred: ${err.message}`);
      }
    }
  }
}

export const invoiceManager = new InvoiceManager(
  path.join(__dirname, "invoices.json"),
);
