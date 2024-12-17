import { Command } from "commander";
import { bundlerClients, publicClients, walletClients } from "./clients";
import { openfortAccountFactory, owner, isValidChain, demoNFTs, tokenA, paymasters, ownerAccount, chainIDs } from "./constants";
import { Address, numberToHex, parseAbi } from "viem";
import { getAccount } from "./openfortSmartAccount";

import {
  entryPoint06Address,
  getUserOperationHash,
} from "viem/account-abstraction";

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

    const account = await getAccount({
      owner: ownerAccount,
      publicClient: publicClient,
      nonce: nonceHex,
    });

    const accountAddress = await account.getAddress();

    console.log(`Transaction sent: ${hash}`);
    console.log(`Account Address: ${accountAddress}`);
  });

program
  .command("lock-tokens")
  .description("lock tokens on a yield-bearing vault")
  .requiredOption("-t, --token <token>", "token address")
  .requiredOption("-a, --amount <amount>", "amount to lock")
  .action(async ({ token, amount }) => { });

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
  .command("buy-demo-nft")
  .description("buy the demo NFT anywhere")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "optimism"]),
  )
  .requiredOption("-i, --ipfs-hash <ipfs-hash>", "ipfs hash")
  .requiredOption("-a, --account <account>", "account address")
  .action(async ({ chain, ipfsHash, account, nonce }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }

    const bundlerClient = bundlerClients[chain];
    const publicClient = publicClients[chain];

    const smartAccount = await getAccount({
      owner: ownerAccount,
      publicClient: publicClient,
      account: account as Address,
    });

    const unsignedUserOp = await bundlerClient.prepareUserOperation({
      account: smartAccount,
      calls: [
        {
          to: tokenA[chain] as Address,
          abi: parseAbi(["function transferFrom(address, address, uint256)"]),
          functionName: "transferFrom",
          args: [paymasters[chain] as Address, account, 1n],
        },
        {
          to: tokenA[chain] as Address,
          abi: parseAbi(["function approve(address, uint256)"]),
          functionName: "approve",
          args: [demoNFTs[chain] as Address, 500n]
        },
        {
          to: demoNFTs[chain] as Address,
          abi: parseAbi(["function mint(address)"]),
          functionName: "mint",
          args: [account],
        }
      ],
      verificationGasLimit: 10000000n,
    });

    const userOpHash = await getUserOperationHash({
      chainId: chainIDs[chain],
      entryPointAddress: entryPoint06Address,
      entryPointVersion: "0.6",
      userOperation: {
        ...(unsignedUserOp as any),
        sender: await smartAccount.getAddress(),
      },
    });
    const signature = await ownerAccount.signMessage({
      message: { raw: userOpHash },
    });
    const hash = await bundlerClient.sendUserOperation({
      ...unsignedUserOp,
      signature,
    });
    console.log(`UserOp sent: ${hash}`);
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
