import type { Account, Address, Hex, PublicClient } from "viem";
import { encodeFunctionData, decodeFunctionData, parseAbi } from "viem/utils";

import {
  entryPoint06Abi,
  entryPoint06Address,
  getUserOperationHash,
} from "viem/account-abstraction";
import type { UserOperation } from "viem/account-abstraction";
import { toSmartAccount } from "viem/account-abstraction";

import { openfortAccountFactory } from "./constants";


type OwnerAndClient = {
  owner: Account;
  publicClient: PublicClient;
}

export type DeployedAccountParams = OwnerAndClient & {
  account: Address;
}

export type NewAccountParams = OwnerAndClient & {
  nonce: Hex;
}

type AccountParams = NewAccountParams | DeployedAccountParams;

function isDeployedAccount(params: AccountParams): params is DeployedAccountParams {
  return "account" in params;
}

export async function getAccount(params: AccountParams) {

  const account = await toSmartAccount({
    client: params.publicClient,
    entryPoint: {
      abi: entryPoint06Abi,
      address: entryPoint06Address,
      version: "0.6",
    },

    async encodeCalls(calls) {
      if (calls.length === 1) {
        // decode data to know if the functionName is registerSessionKey or revokeSessionKey or execute
        // biome-ignore lint/suspicious/noImplicitAnyLet: <explanation>
        let decodeResult;
        try {
          decodeResult = calls[0].data
            ? decodeFunctionData({
              abi: abi,
              data: calls[0].data,
            })
            : undefined;
        } catch (e) { }
        if (
          decodeResult &&
          ["registerSessionKey", "revokeSessionKey"].includes(
            decodeResult.functionName,
          )
        ) {
          // biome-ignore lint/style/noNonNullAssertion: <explanation>
          return calls[0].data!;
        }
        return encodeFunctionData({
          abi,
          functionName: "execute",
          args: [calls[0].to, calls[0].value ?? 0n, calls[0].data ?? "0x"],
        });
      }
      return encodeFunctionData({
        abi,
        functionName: "executeBatch",
        args: [
          calls.map((call) => call.to),
          calls.map((call) => call.value ?? 0n),
          calls.map((call) => call.data ?? "0x"),
        ],
      });
    },

    // TODO: cache the account address
    async getAddress() {
      if (isDeployedAccount(params)) return params.account;
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
      return await params.publicClient.readContract({
        address: openfortAccountFactory,
        abi: abi,
        functionName: "getAddressWithNonce",
        args: [params.owner.address, params.nonce],
      }) as Address;

    },

    async getFactoryArgs() {
      if (isDeployedAccount(params)) return { factory: undefined, factoryData: undefined };
      if (!params.owner || !params.nonce) throw new Error("[getFactoryArgs] Owner or nonceHex not available");
      const factoryData = encodeFunctionData({
        abi: factoryAbi,
        functionName: "createAccountWithNonce",
        args: [params.owner.address, params.nonce, false],
      });
      return { factory: openfortAccountFactory, factoryData };
    },

    async getNonce({ key = 0n } = {}) {
      const address = await this.getAddress();
      const nonce = await params.publicClient.readContract({
        abi: parseAbi([
          "function getNonce(address, uint192) pure returns (uint256)",
        ]),
        address: entryPoint06Address,
        functionName: "getNonce",
        args: [address, key],
      });
      return nonce;
    },

    async getStubSignature() {
      return "0xfffffffffffffffffffffffffffffff0000000000000000000000000000000007aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1c";
    },

    async signMessage(message) {
      if (!params.owner || !params.owner.signMessage)
        throw new Error("Authority does not have signMessage method");
      return await params.owner.signMessage(message);
    },

    async signTypedData(typedData) {
      throw new Error("Not implemented");
    },

    async signUserOperation(userOperation) {
      if (!params.owner || !params.owner.signMessage)
        throw new Error("Authority does not have signMessage method");
      const hash = getUserOperationHash({
        chainId: params.publicClient.chain!.id,
        entryPointAddress: entryPoint06Address,
        entryPointVersion: "0.6",
        userOperation: {
          ...(userOperation as unknown as UserOperation),
          sender: await this.getAddress(),
        },
      });
      const signature = await params.owner.signMessage({ message: { raw: hash } });
      return signature;
    },
  });
  return account;
}

const abi = [
  {
    inputs: [],
    name: "AccountLocked",
    type: "error",
  },
  {
    inputs: [],
    name: "AccountNotLocked",
    type: "error",
  },
  {
    inputs: [],
    name: "CannotUnlock",
    type: "error",
  },
  {
    inputs: [],
    name: "DuplicatedGuardian",
    type: "error",
  },
  {
    inputs: [],
    name: "DuplicatedProposal",
    type: "error",
  },
  {
    inputs: [],
    name: "DuplicatedRevoke",
    type: "error",
  },
  {
    inputs: [],
    name: "GuardianCannotBeOwner",
    type: "error",
  },
  {
    inputs: [],
    name: "InsecurePeriod",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "amountRequired",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "currentBalance",
        type: "uint256",
      },
    ],
    name: "InsufficientBalance",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidParameterLength",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidRecoverySignatures",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidSignatureAmount",
    type: "error",
  },
  {
    inputs: [],
    name: "MustBeGuardian",
    type: "error",
  },
  {
    inputs: [],
    name: "MustSendNativeToken",
    type: "error",
  },
  {
    inputs: [],
    name: "NoOngoingRecovery",
    type: "error",
  },
  {
    inputs: [],
    name: "NotAContract",
    type: "error",
  },
  {
    inputs: [],
    name: "NotOwner",
    type: "error",
  },
  {
    inputs: [],
    name: "NotOwnerOrEntrypoint",
    type: "error",
  },
  {
    inputs: [],
    name: "OngoingRecovery",
    type: "error",
  },
  {
    inputs: [],
    name: "OwnerNotAllowed",
    type: "error",
  },
  {
    inputs: [],
    name: "PendingProposalExpired",
    type: "error",
  },
  {
    inputs: [],
    name: "PendingProposalNotOver",
    type: "error",
  },
  {
    inputs: [],
    name: "PendingRevokeExpired",
    type: "error",
  },
  {
    inputs: [],
    name: "PendingRevokeNotOver",
    type: "error",
  },
  {
    inputs: [],
    name: "UnknownProposal",
    type: "error",
  },
  {
    inputs: [],
    name: "UnknownRevoke",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddressNotAllowed",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroValueNotAllowed",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "creator",
        type: "address",
      },
    ],
    name: "AccountImplementationDeployed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "previousAdmin",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "AdminChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "beacon",
        type: "address",
      },
    ],
    name: "BeaconUpgraded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [],
    name: "EIP712DomainChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "oldEntryPoint",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newEntryPoint",
        type: "address",
      },
    ],
    name: "EntryPointUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "guardian",
        type: "address",
      },
    ],
    name: "GuardianAdded",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "guardian",
        type: "address",
      },
    ],
    name: "GuardianProposalCancelled",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "guardian",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "executeAfter",
        type: "uint256",
      },
    ],
    name: "GuardianProposed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "guardian",
        type: "address",
      },
    ],
    name: "GuardianRevocationCancelled",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "guardian",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "executeAfter",
        type: "uint256",
      },
    ],
    name: "GuardianRevocationRequested",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "guardian",
        type: "address",
      },
    ],
    name: "GuardianRevoked",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint8",
        name: "version",
        type: "uint8",
      },
    ],
    name: "Initialized",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bool",
        name: "isLocked",
        type: "bool",
      },
    ],
    name: "Locked",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferStarted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "recoveryAddress",
        type: "address",
      },
    ],
    name: "RecoveryCancelled",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "recoveryAddress",
        type: "address",
      },
    ],
    name: "RecoveryCompleted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "recoveryAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint64",
        name: "executeAfter",
        type: "uint64",
      },
    ],
    name: "RecoveryExecuted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "key",
        type: "address",
      },
    ],
    name: "SessionKeyRegistered",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "key",
        type: "address",
      },
    ],
    name: "SessionKeyRevoked",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "implementation",
        type: "address",
      },
    ],
    name: "Upgraded",
    type: "event",
  },
  {
    inputs: [],
    name: "acceptOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_guardian",
        type: "address",
      },
    ],
    name: "cancelGuardianProposal",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_guardian",
        type: "address",
      },
    ],
    name: "cancelGuardianRevocation",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "cancelRecovery",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes[]",
        name: "_signatures",
        type: "bytes[]",
      },
    ],
    name: "completeRecovery",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_guardian",
        type: "address",
      },
    ],
    name: "confirmGuardianProposal",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_guardian",
        type: "address",
      },
    ],
    name: "confirmGuardianRevocation",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "eip712Domain",
    outputs: [
      {
        internalType: "bytes1",
        name: "fields",
        type: "bytes1",
      },
      {
        internalType: "string",
        name: "name",
        type: "string",
      },
      {
        internalType: "string",
        name: "version",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "chainId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "verifyingContract",
        type: "address",
      },
      {
        internalType: "bytes32",
        name: "salt",
        type: "bytes32",
      },
      {
        internalType: "uint256[]",
        name: "extensions",
        type: "uint256[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "entryPoint",
    outputs: [
      {
        internalType: "contract IEntryPoint",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "dest",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "func",
        type: "bytes",
      },
    ],
    name: "execute",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address[]",
        name: "_target",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "_value",
        type: "uint256[]",
      },
      {
        internalType: "bytes[]",
        name: "_calldata",
        type: "bytes[]",
      },
    ],
    name: "executeBatch",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [],
    name: "getDeposit",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getGuardians",
    outputs: [
      {
        internalType: "address[]",
        name: "",
        type: "address[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getLock",
    outputs: [
      {
        internalType: "uint256",
        name: "_releaseAfter",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getNonce",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "guardianCount",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_defaultAdmin",
        type: "address",
      },
      {
        internalType: "address",
        name: "_entrypoint",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_recoveryPeriod",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_securityPeriod",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_securityWindow",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_lockPeriod",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "_initialGuardian",
        type: "address",
      },
    ],
    name: "initialize",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_guardian",
        type: "address",
      },
    ],
    name: "isGuardian",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "isLocked",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "_hash",
        type: "bytes32",
      },
      {
        internalType: "bytes",
        name: "_signature",
        type: "bytes",
      },
    ],
    name: "isValidSignature",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "lock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "",
        type: "uint256[]",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "onERC1155BatchReceived",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "onERC1155Received",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "onERC721Received",
    outputs: [
      {
        internalType: "bytes4",
        name: "",
        type: "bytes4",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pendingOwner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_guardian",
        type: "address",
      },
    ],
    name: "proposeGuardian",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "proxiableUUID",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "recoveryDetails",
    outputs: [
      {
        internalType: "address",
        name: "recoveryAddress",
        type: "address",
      },
      {
        internalType: "uint64",
        name: "executeAfter",
        type: "uint64",
      },
      {
        internalType: "uint32",
        name: "guardiansRequired",
        type: "uint32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_key",
        type: "address",
      },
      {
        internalType: "uint48",
        name: "_validAfter",
        type: "uint48",
      },
      {
        internalType: "uint48",
        name: "_validUntil",
        type: "uint48",
      },
      {
        internalType: "uint48",
        name: "_limit",
        type: "uint48",
      },
      {
        internalType: "address[]",
        name: "_whitelist",
        type: "address[]",
      },
    ],
    name: "registerSessionKey",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_guardian",
        type: "address",
      },
    ],
    name: "revokeGuardian",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_key",
        type: "address",
      },
    ],
    name: "revokeSessionKey",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sessionKey",
        type: "address",
      },
    ],
    name: "sessionKeys",
    outputs: [
      {
        internalType: "uint48",
        name: "validAfter",
        type: "uint48",
      },
      {
        internalType: "uint48",
        name: "validUntil",
        type: "uint48",
      },
      {
        internalType: "uint48",
        name: "limit",
        type: "uint48",
      },
      {
        internalType: "bool",
        name: "masterSessionKey",
        type: "bool",
      },
      {
        internalType: "bool",
        name: "whitelisting",
        type: "bool",
      },
      {
        internalType: "address",
        name: "registrarAddress",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_recoveryAddress",
        type: "address",
      },
    ],
    name: "startRecovery",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "tokensReceived",
    outputs: [],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "unlock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_newEntrypoint",
        type: "address",
      },
    ],
    name: "updateEntryPoint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newImplementation",
        type: "address",
      },
    ],
    name: "upgradeTo",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newImplementation",
        type: "address",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "upgradeToAndCall",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        components: [
          {
            internalType: "address",
            name: "sender",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "nonce",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "initCode",
            type: "bytes",
          },
          {
            internalType: "bytes",
            name: "callData",
            type: "bytes",
          },
          {
            internalType: "uint256",
            name: "callGasLimit",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "verificationGasLimit",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "preVerificationGas",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "maxFeePerGas",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "maxPriorityFeePerGas",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "paymasterAndData",
            type: "bytes",
          },
          {
            internalType: "bytes",
            name: "signature",
            type: "bytes",
          },
        ],
        internalType: "struct UserOperation",
        name: "userOp",
        type: "tuple",
      },
      {
        internalType: "bytes32",
        name: "userOpHash",
        type: "bytes32",
      },
      {
        internalType: "uint256",
        name: "missingAccountFunds",
        type: "uint256",
      },
    ],
    name: "validateUserOp",
    outputs: [
      {
        internalType: "uint256",
        name: "validationData",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    stateMutability: "payable",
    type: "receive",
  },
] as const;


const factoryAbi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "_entrypoint",
        type: "address",
      },
      {
        internalType: "address",
        name: "_accountImplementation",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_recoveryPeriod",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_securityPeriod",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_securityWindow",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_lockPeriod",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "_initialGuardian",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "InsecurePeriod",
    type: "error",
  },
  {
    inputs: [],
    name: "NotAContract",
    type: "error",
  },
  {
    inputs: [],
    name: "TooManyInitialGuardians",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddressNotAllowed",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "accountAdmin",
        type: "address",
      },
    ],
    name: "AccountCreated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "oldInitialGuardian",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newInitialGuardian",
        type: "address",
      },
    ],
    name: "InitialGuardianUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferStarted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    inputs: [],
    name: "acceptOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint32",
        name: "unstakeDelaySec",
        type: "uint32",
      },
    ],
    name: "addStake",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_admin",
        type: "address",
      },
      {
        internalType: "bytes32",
        name: "_nonce",
        type: "bytes32",
      },
      {
        internalType: "bool",
        name: "_initializeGuardian",
        type: "bool",
      },
    ],
    name: "createAccountWithNonce",
    outputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "entrypointContract",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_admin",
        type: "address",
      },
      {
        internalType: "bytes32",
        name: "_nonce",
        type: "bytes32",
      },
    ],
    name: "getAddressWithNonce",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "implementation",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "initialGuardian",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "lockPeriod",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pendingOwner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "recoveryPeriod",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "securityPeriod",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "securityWindow",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "unlockStake",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_newInitialGuardian",
        type: "address",
      },
    ],
    name: "updateInitialGuardian",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address payable",
        name: "withdrawAddress",
        type: "address",
      },
    ],
    name: "withdrawStake",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;