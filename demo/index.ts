import { Command } from "commander";
import { publicClients, walletClients } from "./clients";
import { openfortAccountFactory, owner, isValidChain } from "./constants";
import { numberToHex, parseAbi } from "viem";

const figlet = require("figlet");
const program = new Command();

console.log(figlet.textSync("Chain Abstraction"));

program
  .name("openfort-chain-abstraction")
  .description(
    "A simple CLI to explore chain abstraction with Openfort 4337 Smart Account",
  )
  .version("1.0.0");

program
  .command("create-account")
  .description("create openfort smart account")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "optimism"]),
  )
  .requiredOption("-n, --nonce <nonce>", "nonce")
  .action(async ({ chain, nonce }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }

    const walletClient = walletClients[chain];
    const publicClient = publicClients[chain];

    const nonceHex = numberToHex(nonce, { size: 32 });
    const hash = await walletClient.writeContract({
      address: openfortAccountFactory,
      abi: parseAbi([
        "function createAccountWithNonce(address, bytes32, bool)",
      ]),
      functionName: "createAccountWithNonce",
      args: [owner, nonceHex, false],
      chain: walletClient.chain,
      account: walletClient.account || null,
    });

    console.log(`Transaction sent: ${hash}`);
    try {
      const abi = [
        {
          inputs: [
            { name: "_admin", type: "address" },
            { name: "_nonce", type: "bytes32" },
          ],
          name: "getAddressWithNonce",
          outputs: [{ type: "address" }],
          stateMutability: "view",
          type: "function",
        },
      ];
      const accountAddress = await publicClient.readContract({
        address: openfortAccountFactory,
        abi: abi,
        functionName: "getAddressWithNonce",
        args: [owner, nonceHex],
      });
      console.log(`Account address: ${accountAddress}`);
    } catch (error) {
      console.error("Error calling contract:", error);
    }
  });

program
  .command("lock-tokens")
  .description("lock tokens on a yield-bearing vault")
  .requiredOption("-t, --token <token>", "token address")
  .requiredOption("-a, --amount <amount>", "amount to lock")
  .action(async ({ token, amount }) => {});

program
  .command("get-chain-abstraction-balance")
  .description("get chain abstraction balance")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "optimism"]),
  )
  .action(async ({ chain }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }

    const walletClient = walletClients[chain];
    const publicClient = publicClients[chain];

    console.log("WIP");
  });

program
  .command("buy-openfort-NFT")
  .description("buy a game NFT anywhere")
  .action(async () => {
    console.log("WIP");
  });

program
  .command("get-userop-execution-proof")
  .description("call Polymer API to get a userOp execution proof")
  .action(async () => {
    console.log("WIP");
  });

program
  .command("mint-token")
  .description("mint amount of token to a recipient")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "optimism"]),
  )
  .requiredOption("-t, --token <token>", "token address")
  .requiredOption("-a, --amount <amount>", "amount to send")
  .requiredOption("-r, --recipient <recipient>", "recipient address")
  .action(async ({ chain, token, amount, recipient }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    const walletClient = walletClients[chain];

    const hash = await walletClient.writeContract({
      address: token,
      abi: parseAbi(["function mint(address, uint256)"]),
      functionName: "mint",
      args: [recipient, amount],
      chain: walletClient.chain,
      account: walletClient.account || null,
    });
    console.log(`Sending ${amount} tokens to ${recipient} on ${chain}`);
    console.log(`Transaction sent: ${hash}`);
  });

program
  .command("refund-paymaster")
  .description("call invoice manager to refund paymaster")
  .requiredOption("-i, --invoice-id <invoice-id>", "invoice id")
  .action(async ({ invoiceId }) => {
    console.log("WIP");
  });

program.parse();
