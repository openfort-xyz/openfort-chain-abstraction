import { Command } from "commander";
import { polymerProverClient } from "./polymerProverClient";
import { bundlerClients, publicClients, walletClients } from "./viemClients";
import { isValidChain, demoNFTs, tokenA, paymasters, ownerAccount, chainIDs, V7SimpleAccountFactoryAddress, openfortContracts } from "./constants";
import { Address, getAddress, Hex, parseAbi } from "viem";
import { toSimpleSmartAccount } from "./SimpleSmartAccount";
import {
  entryPoint07Address,
  getUserOperationHash,
} from "viem/account-abstraction";

import util from "util";

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
  .requiredOption("-s, --account-salt <salt>", "account salt")
  .action(async ({ chain, accountSalt }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    const publicClient = publicClients[chain];
    const account = await toSimpleSmartAccount({
      client: publicClient,
      owner: ownerAccount,
      salt: accountSalt,
      entryPoint: {
        address: entryPoint07Address,
        version: "0.7",
      },
    });

    const accountAddress = await account.getAddress();
    console.log(`Account Address: ${accountAddress}`);
  });

program
  .command("lock-tokens")
  .description("lock tokens on a yield-bearing vault")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "optimism"]),
  )
  .requiredOption("-t, --token <token>", "token address")
  .requiredOption("-a, --amount <amount>", "amount to lock")
  .requiredOption("-s, --account-salt <salt>", "account salt")
  .action(async ({ token, amount, chain, accountSalt }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }

    if (!(token in openfortContracts[chain].vaults)) {
      throw new Error(`Token ${token} not supported on ${chain}`);
    }

    const vaultManager = openfortContracts[chain].vaultManager;
    const vault = openfortContracts[chain].vaults[token];
    const publicClient = publicClients[chain];
    const account = await toSimpleSmartAccount({
      client: publicClient,
      owner: ownerAccount,
      salt: accountSalt,
      entryPoint: {
        address: entryPoint07Address,
        version: "0.7",
      },
    });

    const accountAddress = await account.getAddress();
    console.log(`Account Address: ${accountAddress}`);

    const bundlerClient = bundlerClients[chain];
    const unsignedUserOp = await bundlerClient.prepareUserOperation({
      account: account,
      calls: [
        {
          to: vaultManager,
          abi: parseAbi(["function deposit(address, address, uint256, bool)"]),
          functionName: "deposit",
          args: [getAddress(token), getAddress(vault), amount, false],
        }
      ]
    })

    const userOpHash = await getUserOperationHash({
      chainId: chainIDs[chain],
      entryPointAddress: entryPoint07Address,
      entryPointVersion: "0.7",
      userOperation: {
        ...(unsignedUserOp as any),
        sender: await account.getAddress(),
      },
    });

    const signature = await ownerAccount.signMessage({
      message: { raw: userOpHash },
    });

    const hash = await bundlerClient.sendUserOperation({
      ...unsignedUserOp,
      signature,
      account: account,
    });
    console.log(`UserOp sent: ${hash}`);
  });


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
  .requiredOption("-s, --account-salt <salt>", "account salt")
  .action(async ({ chain, ipfsHash, accountSalt }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    const nftPrice = 500n;
    const bundlerClient = bundlerClients[chain];
    const publicClient = publicClients[chain];
    const account = await toSimpleSmartAccount({
      owner: ownerAccount,
      client: publicClient,
      salt: accountSalt,
      factoryAddress: V7SimpleAccountFactoryAddress,
      entryPoint: {
        address: entryPoint07Address,
        version: "0.7",
      },
    });
    const accountAddress = await account.getAddress();
    console.log(`Account Address: ${accountAddress}`);
    const unsignedUserOp = await bundlerClient.prepareUserOperation({
      account: account,
      calls: [
        {
          to: tokenA[chain] as Address,
          abi: parseAbi(["function transferFrom(address, address, uint256)"]),
          functionName: "transferFrom",
          args: [paymasters[chain] as Address, accountAddress, nftPrice],
        },
        {
          to: tokenA[chain] as Address,
          abi: parseAbi(["function approve(address, uint256)"]),
          functionName: "approve",
          args: [demoNFTs[chain] as Address, nftPrice]
        },
        {
          to: demoNFTs[chain] as Address,
          abi: parseAbi(["function mint(string)"]),
          functionName: "mint",
          args: [ipfsHash],
        }
      ],
      verificationGasLimit: 1000000n,
      postVerificationGasLimit: 1000000n,
      preVerificationGas: 1000000n,
      callGasLimit: 1000000n,
      /** Concatenation of {@link UserOperation`verificationGasLimit`} (16 bytes) and {@link UserOperation`callGasLimit`} (16 bytes) */
      accountGasLimits: `0x${1000000n.toString(16)}${1000000n.toString(16)}` as Hex,
    });

    const userOpHash = await getUserOperationHash({
      chainId: chainIDs[chain],
      entryPointAddress: entryPoint07Address,
      entryPointVersion: "0.7",
      userOperation: {
        ...(unsignedUserOp as any),
        sender: await account.getAddress(),
      },
    });
    const signature = await ownerAccount.signMessage({
      message: { raw: userOpHash },
    });

    const hash = await bundlerClient.sendUserOperation({
      ...unsignedUserOp,
      signature,
      account: account,
    });
    console.log(`UserOp sent: ${hash}`);
  });

program
  .command("request-receipt-proof")
  .description("request receipt proof from Polymer")
  .requiredOption("-s, --src-chain <src-chain-id>", "source chain id")
  .requiredOption("-d, --dst-chain <dst-chain-id>", "destination chain id")
  .requiredOption("-b, --src-block <src-block-number>", "source block number")
  .requiredOption("-t, --tx-index <tx-index>", "transaction index")
  .action(async ({ srcChain, dstChain, srcBlock, txIndex }) => {
    const jobId = await polymerProverClient.receiptRequestProof(srcChain, dstChain, srcBlock, txIndex);
    console.log(`jobId: ${jobId}`);
  });

program
  .command("query-receipt-proof")
  .description("query receipt proof with jobId from Polymer")
  .requiredOption("-j, --job-id <job-id>", "job id")
  .action(async ({ jobId }) => {
    const proofResponse = await polymerProverClient.queryReceiptProof(jobId);
    console.log(util.inspect(proofResponse, { showHidden: true, depth: null, colors: true }));
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


program
  .command("get-invoices")
  .description("get invoices from paymaster")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "optimism"]),
  )
  .action(async ({ chain }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    const paymaster = openfortContracts[chain].paymaster;
    console.log({ paymaster });
    console.log(parseAbi(["event InvoiceCreated(bytes32 indexed invoiceId)"]));
    const publicClient = publicClients[chain];
    const logs = await publicClient.getLogs({
      address: paymaster,
    });
    console.log(util.inspect(logs, { showHidden: true, depth: null, colors: true }));
  });

program.parse();
