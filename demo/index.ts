import { Command } from "commander";
import { polymerProverClient } from "./polymerProverClient";
import { bundlerClients, publicClients, walletClients } from "./viemClients";
import {
  isValidChain,
  demoNFTs,
  tokenA,
  ownerAccount,
  chainIDs,
  V7SimpleAccountFactoryAddress,
  openfortContracts,
  vaultA,
} from "./constants";
import { Address, Hex, parseAbi } from "viem";
import { toSimpleSmartAccount } from "./SimpleSmartAccount";
import {
  entryPoint07Address,
  getUserOperationHash,
} from "viem/account-abstraction";

import util from "util";
import { invoiceManager } from "./Invoice";
import { getBlockNumber, getBlockTimestamp } from "./utils";

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
      .choices(["base", "mantle", "optimism", "polygon"]),
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
      .choices(["base", "mantle", "optimism", "polygon"]),
  )
  .requiredOption("-t, --token <token>", "token address")
  .requiredOption("-a, --amount <amount>", "amount to lock")
  .requiredOption("-r, --recipient <recipient>", "recipient address")
  .action(async ({ token, amount, chain, recipient }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }

    if (!(token in openfortContracts[chain].vaults)) {
      throw new Error(`Token ${token} not supported on ${chain}`);
    }

    const vaultManager = openfortContracts[chain].vaultManager;
    const vault = openfortContracts[chain].vaults[token];
    const walletClient = walletClients[chain];
    const publicClient = publicClients[chain];

    const nonce = await publicClient.getTransactionCount({
      address: walletClient.account?.address as Address,
    });

    const approveHash = await walletClient.writeContract({
      address: token,
      abi: parseAbi(["function approve(address, uint256)"]),
      functionName: "approve",
      args: [vaultManager, amount],
      chain: walletClient.chain,
      account: walletClient.account || null,
      nonce,
    });
    console.log(`Approve transaction sent: ${approveHash}`);

    const hash = await walletClient.writeContract({
      address: vaultManager,
      abi: parseAbi([
        "function depositFor(address, address, address, uint256, bool)",
      ]),
      functionName: "depositFor",
      args: [recipient, token, vault, amount, false],
      chain: walletClient.chain,
      account: walletClient.account || null,
      nonce: nonce + 1,
    });
    console.log(`Deposit transaction sent: ${hash}`);
  });

program
  .command("get-chain-abstraction-balance")
  .description("get chain abstraction balance")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "mantle", "optimism", "polygon"]),
  )
  .action(async ({ chain }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    // TODO: read balance in all vaults
    console.log("WIP");
  });

program
  .command("buy-demo-nft")
  .description("buy the demo NFT anywhere")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "mantle", "optimism", "polygon"]),
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
    const paymaster = openfortContracts[chain].cabPaymaster;
    console.log(`Paymaster: ${paymaster}`);

    let calls = [];
    if (chain === "mantle") {
      calls = [
        {
          to: demoNFTs[chain] as Address,
          abi: parseAbi(["function mint(string)"]),
          functionName: "mint",
          args: [ipfsHash],
          value: nftPrice, // DEMO: pay with native token on Mantle
        },
      ];
    } else {
      // On optimism and base, keep paying with ERC20 tokens
      calls = [
        {
          to: tokenA[chain] as Address,
          abi: parseAbi(["function transferFrom(address, address, uint256)"]),
          functionName: "transferFrom",
          args: [paymaster, accountAddress, nftPrice],
        },
        {
          to: tokenA[chain] as Address,
          abi: parseAbi(["function approve(address, uint256)"]),
          functionName: "approve",
          args: [demoNFTs[chain] as Address, nftPrice],
        },
        {
          to: demoNFTs[chain] as Address,
          abi: parseAbi(["function mint(string)"]),
          functionName: "mint",
          args: [ipfsHash],
        },
      ];
    }

    const unsignedUserOp = await bundlerClient.prepareUserOperation({
      account: account,
      calls: calls,
      // NOTE: commet following fields to run on MANTLE
      verificationGasLimit: 1000000n,
      postVerificationGasLimit: 1000000n,
      preVerificationGas: 1000000n,
      callGasLimit: 1000000n,
      paymasterPostOpGasLimit: 1000000n,
      /** Concatenation of {@link UserOperation`verificationGasLimit`} (16 bytes) and {@link UserOperation`callGasLimit`} (16 bytes) */
      accountGasLimits:
        `0x${1000000n.toString(16)}${1000000n.toString(16)}` as Hex,
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
    //  TODO: support multiple source chains
    const srcChain = "polygon";
    const invoiceId = await invoiceManager.writeInvoice({
      account: accountAddress,
      nonce: BigInt(unsignedUserOp.nonce),
      paymaster: openfortContracts[chain].cabPaymaster,
      sponsorChainId: BigInt(chainIDs[chain]),
      repayTokenInfos: [
        {
          vault: vaultA[srcChain] as Address,
          amount: nftPrice,
          chainId: BigInt(chainIDs[srcChain]),
        },
      ],
    });
    console.log(`Invoice ID: ${invoiceId}`);
  });

program
  .command("request-event-proof")
  .description("request receipt proof from Polymer")
  .requiredOption("-s, --src-chain <src-chain-id>", "source chain id")
  .requiredOption("-b, --src-block <src-block-number>", "source block number")
  .requiredOption("-t, --tx-index <tx-index>", "transaction index")
  .requiredOption("-l, --log-index <log-index>", "log index")
  .action(async ({ srcChain, srcBlock, txIndex, logIndex }) => {
    const jobId = await polymerProverClient.requestEventProof(
      srcChain,
      srcBlock,
      txIndex,
      logIndex,
    );
    console.log(`jobId: ${jobId}`);
  });

program
  .command("fetch-event-proof")
  .description("fetch event proof with jobId from Polymer")
  .requiredOption("-j, --job-id <job-id>", "job id")
  .action(async ({ jobId }) => {
    const proofResponse = await polymerProverClient.fetchEventProof(jobId);
    console.log(
      util.inspect(proofResponse, {
        showHidden: true,
        depth: null,
        colors: true,
        maxStringLength: null,
      }),
    );
  });

program
  .command("mint-token")
  .description("mint amount of token to a recipient")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "mantle", "optimism", "polygon"]),
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
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "mantle", "optimism", "polygon"]),
  )
  .requiredOption("-p, --proof <proof>", "proof")
  .requiredOption("-i, --invoice-id <invoice-id>", "invoice id")
  .action(async ({ chain, proof, invoiceId }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    const invoiceWithRepayTokens = await invoiceManager.readInvoice(invoiceId);

    console.log("invoiceWithRepayTokens");
    console.log(invoiceWithRepayTokens);
    const walletClient = walletClients[chain];

    const hash = await walletClient.writeContract({
      address: openfortContracts[chain].invoiceManager,
      abi: parseAbi([
        "struct RepayTokenInfo { address vault; uint256 amount; uint256 chainId; }",
        "struct InvoiceWithRepayTokens { address account; uint256 nonce; address paymaster; uint256 sponsorChainId; RepayTokenInfo[] repayTokenInfos; }",
        "function repay(bytes32 invoiceId, InvoiceWithRepayTokens invoice, bytes proof)",
      ]),
      functionName: "repay",
      args: [invoiceId, invoiceWithRepayTokens, proof],
      chain: walletClient.chain,
      account: walletClient.account || null,
    });
    console.log(`Transaction sent: ${hash}`);
  });

program
  .command("get-invoices")
  .description(
    "read blockchain to get invoices-id from paymaster contract events",
  )
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "mantle", "optimism", "polygon"]),
  )
  .action(async ({ chain }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    const invoiceManager = openfortContracts[chain].invoiceManager;
    const publicClient = publicClients[chain];

    const currentBlock = await getBlockNumber(chain);

    const logs = await publicClient.getLogs({
      address: invoiceManager,
      event: parseAbi([
        "event InvoiceCreated(bytes32 indexed invoiceId, address indexed account, address indexed paymaster)",
      ])[0],
      fromBlock: currentBlock - 10000n,
      toBlock: currentBlock,
    });

    console.log(
      util.inspect(logs, { showHidden: true, depth: null, colors: true }),
    );
  });

program
  .command("register-paymaster")
  .description("register paymaster")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "mantle", "optimism", "polygon"]),
  )
  .requiredOption("-s, --account-salt <salt>", "account salt")
  .addOption(
    new Command()
      .createOption("-p, --prover <prover>", "choose prover")
      .choices(["hashi", "polymer"]),
  )
  .action(async ({ chain, accountSalt, prover }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    const publicClient = publicClients[chain];
    const bundlerClient = bundlerClients[chain];
    const paymasterVerifierAddress =
      prover === "hashi"
        ? openfortContracts[chain].hashiPaymasterVerifier
        : openfortContracts[chain].polymerPaymasterVerifier;
    console.log(`paymaster verifier: ${paymasterVerifierAddress}`);

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
          to: openfortContracts[chain].invoiceManager,
          abi: parseAbi([
            "function registerPaymaster(address, address, uint256)",
          ]),
          functionName: "registerPaymaster",
          args: [
            openfortContracts[chain].cabPaymaster,
            paymasterVerifierAddress,
            (await getBlockTimestamp(chain)) + 1000000n,
          ],
        },
      ],
    });

    const userOpHash = await getUserOperationHash({
      chainId: chainIDs[chain],
      entryPointAddress: entryPoint07Address,
      entryPointVersion: "0.7",
      userOperation: {
        ...(unsignedUserOp as any),
        sender: accountAddress,
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
  .command("revoke-paymaster")
  .description("revoke paymaster")
  .addOption(
    new Command()
      .createOption("-c, --chain <chain>", "choose chain")
      .choices(["base", "mantle", "optimism"]),
  )
  .requiredOption("-s, --account-salt <salt>", "account salt")
  .action(async ({ chain, accountSalt }) => {
    if (!isValidChain(chain)) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    const publicClient = publicClients[chain];
    const bundlerClient = bundlerClients[chain];

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
          to: openfortContracts[chain].invoiceManager,
          abi: parseAbi(["function revokePaymaster()"]),
          functionName: "revokePaymaster",
          args: [],
        },
      ],
    });

    const userOpHash = await getUserOperationHash({
      chainId: chainIDs[chain],
      entryPointAddress: entryPoint07Address,
      entryPointVersion: "0.7",
      userOperation: {
        ...unsignedUserOp,
        sender: accountAddress,
      },
    });
    const signature = await ownerAccount.signMessage({
      message: { raw: userOpHash },
    });

    const hash = await bundlerClient.sendUserOperation({
      ...unsignedUserOp,
      signature,
      account: account as any,
    });
    console.log(`UserOp sent: ${hash}`);
  });

program.parse();
