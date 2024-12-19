import {
  type Account,
  type Address,
  type Assign,
  BaseError,
  type Chain,
  type Client,
  type Hex,
  type LocalAccount,
  type OneOf,
  Prettify,
  type Transport,
  type WalletClient,
  concat,
  createWalletClient,
  custom,
  encodeDeployData,
  encodeFunctionData,
  getAddress,
} from "viem"
import { toAccount } from "viem/accounts"
import {
  type SmartAccount,
  type SmartAccountImplementation,
  type UserOperation,
  entryPoint06Abi,
  entryPoint07Abi,
  entryPoint07Address,
  getUserOperationHash,
  toSmartAccount
} from "viem/account-abstraction"
import { getChainId, readContract, signMessage, call, signTypedData } from "viem/actions"
import { getAction } from "viem/utils"

export const getAccountInitCode = async (
  owner: Address,
  salt: bigint
): Promise<Hex> => {
  if (!owner) throw new Error("Owner account not found")

  return encodeFunctionData({
      abi: [
          {
              inputs: [
                  {
                      internalType: "address",
                      name: "owner",
                      type: "address"
                  },
                  {
                      internalType: "uint256",
                      name: "salt",
                      type: "uint256"
                  }
              ],
              name: "createAccount",
              outputs: [
                  {
                      internalType: "contract SimpleAccount",
                      name: "ret",
                      type: "address"
                  }
              ],
              stateMutability: "nonpayable",
              type: "function"
          }
      ],
      functionName: "createAccount",
      args: [owner, salt]
  })
}

export type ToSimpleSmartAccountParameters<
  entryPointVersion extends "0.6" | "0.7"
> = {
  client: Client
  owner: OneOf<
      | EthereumProvider
      | WalletClient<Transport, Chain | undefined, Account>
      | LocalAccount
  >
  factoryAddress?: Address
  entryPoint?: {
      address: Address
      version: entryPointVersion
  }
  salt?: bigint
  address?: Address
  nonceKey?: bigint
}

const getFactoryAddress = (
  entryPointVersion: "0.6" | "0.7",
  factoryAddress?: Address
): Address => {
  if (factoryAddress) return factoryAddress

  if (entryPointVersion === "0.6") {
      return "0x9406Cc6185a346906296840746125a0E44976454"
  }
  return "0x91E60e0613810449d098b0b5Ec8b51A0FE8c8985"
}

export type SimpleSmartAccountImplementation<
  entryPointVersion extends "0.6" | "0.7" = "0.7"
> = Assign<
  SmartAccountImplementation<
      entryPointVersion extends "0.6"
          ? typeof entryPoint06Abi
          : typeof entryPoint07Abi,
      entryPointVersion
      // {
      //     // entryPoint === ENTRYPOINT_ADDRESS_V06 ? "0.2.2" : "0.3.0-beta"
      //     abi: entryPointVersion extends "0.6" ? typeof BiconomyAbi
      //     factory: { abi: typeof FactoryAbi; address: Address }
      // }
  >,
  { sign: NonNullable<SmartAccountImplementation["sign"]> }
>

export type ToSimpleSmartAccountReturnType<
  entryPointVersion extends "0.6" | "0.7" = "0.7"
> = SmartAccount<SimpleSmartAccountImplementation<entryPointVersion>>

/**
* @description Creates an Simple Account from a private key.
*
* @returns A Private Key Simple Account.
*/
export async function toSimpleSmartAccount<
  entryPointVersion extends "0.6" | "0.7"
>(
  parameters: ToSimpleSmartAccountParameters<entryPointVersion>
): Promise<ToSimpleSmartAccountReturnType<entryPointVersion>> {
  const {
      client,
      owner,
      factoryAddress: _factoryAddress,
      salt,
      address,
      nonceKey
  } = parameters

  const localOwner = await toOwner({ owner })

  const entryPoint = {
      address: parameters.entryPoint?.address ?? entryPoint07Address,
      abi:
          (parameters.entryPoint?.version ?? "0.7") === "0.6"
              ? entryPoint06Abi
              : entryPoint07Abi,
      version: parameters.entryPoint?.version ?? "0.7"
  } as const

  const factoryAddress = getFactoryAddress(
      entryPoint.version,
      _factoryAddress
  )

  let accountAddress: Address | undefined = address

  let chainId: number

  const getMemoizedChainId = async () => {
      if (chainId) return chainId
      chainId = client.chain
          ? client.chain.id
          : await getAction(client, getChainId, "getChainId")({})
      return chainId
  }

  const getFactoryArgs = async () => {
      return {
          factory: factoryAddress,
          factoryData: await getAccountInitCode(localOwner.address, salt ?? BigInt(0))
      }
  }

  return toSmartAccount({
      client,
      entryPoint,
      getFactoryArgs,
      async getAddress() {
          if (accountAddress) return accountAddress
          const { factory, factoryData } = await getFactoryArgs()
          // Get the sender address based on the init code
          accountAddress = await getSenderAddress(client, {
              factory,
              factoryData,
              entryPointAddress: entryPoint.address
          })

          return accountAddress
      },
      async encodeCalls(calls) {
          if (calls.length > 1) {
              if (entryPoint.version === "0.6") {
                  return encodeFunctionData({
                      abi: [
                          {
                              inputs: [
                                  {
                                      internalType: "address[]",
                                      name: "dest",
                                      type: "address[]"
                                  },
                                  {
                                      internalType: "bytes[]",
                                      name: "func",
                                      type: "bytes[]"
                                  }
                              ],
                              name: "executeBatch",
                              outputs: [],
                              stateMutability: "nonpayable",
                              type: "function"
                          }
                      ],
                      functionName: "executeBatch",
                      args: [
                          calls.map((a) => a.to),
                          calls.map((a) => a.data ?? "0x")
                      ]
                  })
              }
              return encodeFunctionData({
                  abi: [
                      {
                          inputs: [
                              {
                                  internalType: "address[]",
                                  name: "dest",
                                  type: "address[]"
                              },
                              {
                                  internalType: "uint256[]",
                                  name: "value",
                                  type: "uint256[]"
                              },
                              {
                                  internalType: "bytes[]",
                                  name: "func",
                                  type: "bytes[]"
                              }
                          ],
                          name: "executeBatch",
                          outputs: [],
                          stateMutability: "nonpayable",
                          type: "function"
                      }
                  ],
                  functionName: "executeBatch",
                  args: [
                      calls.map((a) => a.to),
                      calls.map((a) => a.value ?? 0n),
                      calls.map((a) => a.data ?? "0x")
                  ]
              })
          }

          const call = calls.length === 0 ? undefined : calls[0]

          if (!call) {
              throw new Error("No calls to encode")
          }

          return encodeFunctionData({
              abi: [
                  {
                      inputs: [
                          {
                              internalType: "address",
                              name: "dest",
                              type: "address"
                          },
                          {
                              internalType: "uint256",
                              name: "value",
                              type: "uint256"
                          },
                          {
                              internalType: "bytes",
                              name: "func",
                              type: "bytes"
                          }
                      ],
                      name: "execute",
                      outputs: [],
                      stateMutability: "nonpayable",
                      type: "function"
                  }
              ],
              functionName: "execute",
              args: [call.to, call.value ?? 0n, call.data ?? "0x"]
          })
      },
      async getNonce(args) {
          return getAccountNonce(client, {
              address: await this.getAddress(),
              entryPointAddress: entryPoint.address,
              key: nonceKey ?? args?.key
          })
      },
      async getStubSignature() {
          return "0xfffffffffffffffffffffffffffffff0000000000000000000000000000000007aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1c"
      },
      async sign({ hash }) {
          return this.signMessage({ message: hash })
      },
      signMessage: async (_) => {
          throw new Error("Simple account isn't 1271 compliant")
      },
      signTypedData: async (_) => {
          throw new Error("Simple account isn't 1271 compliant")
      },
      async signUserOperation(parameters) {
          const { chainId = await getMemoizedChainId(), ...userOperation } =
              parameters
          return signMessage(client, {
              account: localOwner,
              message: {
                  raw: getUserOperationHash({
                      userOperation: {
                          ...userOperation,
                          sender:
                              userOperation.sender ??
                              (await this.getAddress()),
                          signature: "0x"
                      } as UserOperation<entryPointVersion>,
                      entryPointAddress: entryPoint.address,
                      entryPointVersion: entryPoint.version,
                      chainId: chainId
                  })
              }
          })
      }
  }) as Promise<ToSimpleSmartAccountReturnType<entryPointVersion>>
}


export type GetAccountNonceParams = {
  address: Address
  entryPointAddress: Address
  key?: bigint
}


export const getAccountNonce = async (
  client: Client,
  args: GetAccountNonceParams
): Promise<bigint> => {
  const { address, entryPointAddress, key = BigInt(0) } = args

  return await getAction(
      client,
      readContract,
      "readContract"
  )({
      address: entryPointAddress,
      abi: [
          {
              inputs: [
                  {
                      name: "sender",
                      type: "address"
                  },
                  {
                      name: "key",
                      type: "uint192"
                  }
              ],
              name: "getNonce",
              outputs: [
                  {
                      name: "nonce",
                      type: "uint256"
                  }
              ],
              stateMutability: "view",
              type: "function"
          }
      ],
      functionName: "getNonce",
      args: [address, key]
  })
}


const GetSenderAddressHelperByteCode =
    "0x6080604052604051610302380380610302833981016040819052610022916101de565b600080836001600160a01b0316639b249f6960e01b8460405160240161004891906102b2565b60408051601f198184030181529181526020820180516001600160e01b03166001600160e01b031990941693909317909252905161008691906102e5565b6000604051808303816000865af19150503d80600081146100c3576040519150601f19603f3d011682016040523d82523d6000602084013e6100c8565b606091505b5091509150600082610148576004825111156100ef5760248201519050806000526014600cf35b60405162461bcd60e51b8152602060048201526024808201527f67657453656e64657241646472657373206661696c656420776974686f7574206044820152636461746160e01b60648201526084015b60405180910390fd5b60405162461bcd60e51b815260206004820152602b60248201527f67657453656e6465724164647265737320646964206e6f74207265766572742060448201526a185cc8195e1c1958dd195960aa1b606482015260840161013f565b634e487b7160e01b600052604160045260246000fd5b60005b838110156101d55781810151838201526020016101bd565b50506000910152565b600080604083850312156101f157600080fd5b82516001600160a01b038116811461020857600080fd5b60208401519092506001600160401b0381111561022457600080fd5b8301601f8101851361023557600080fd5b80516001600160401b0381111561024e5761024e6101a4565b604051601f8201601f19908116603f011681016001600160401b038111828210171561027c5761027c6101a4565b60405281815282820160200187101561029457600080fd5b6102a58260208301602086016101ba565b8093505050509250929050565b60208152600082518060208401526102d18160408501602087016101ba565b601f01601f19169190910160400192915050565b600082516102f78184602087016101ba565b919091019291505056fe"

const GetSenderAddressHelperAbi = [
    {
        inputs: [
            {
                internalType: "address",
                name: "_entryPoint",
                type: "address"
            },
            {
                internalType: "bytes",
                name: "initCode",
                type: "bytes"
            }
        ],
        stateMutability: "payable",
        type: "constructor"
    }
]

export type GetSenderAddressParams = OneOf<
    | {
          initCode: Hex
          entryPointAddress: Address
          factory?: never
          factoryData?: never
      }
    | {
          entryPointAddress: Address
          factory: Address
          factoryData: Hex
          initCode?: never
      }
>

export class InvalidEntryPointError extends BaseError {
    override name = "InvalidEntryPointError"

    constructor({
        cause,
        entryPointAddress
    }: { cause?: BaseError; entryPointAddress?: Address } = {}) {
        super(
            `The entry point address (\`entryPoint\`${
                entryPointAddress ? ` = ${entryPointAddress}` : ""
            }) is not a valid entry point. getSenderAddress did not revert with a SenderAddressResult error.`,
            {
                cause
            }
        )
    }
}

export const getSenderAddress = async (
    client: Client,
    args: Prettify<GetSenderAddressParams>
): Promise<Address> => {
    const { initCode, entryPointAddress, factory, factoryData } = args

    if (!initCode && !factory && !factoryData) {
        throw new Error(
            "Either `initCode` or `factory` and `factoryData` must be provided"
        )
    }

    const formattedInitCode =
        initCode || concat([factory as Hex, factoryData as Hex])

    const { data } = await getAction(
        client,
        call,
        "call"
    )({
        data: encodeDeployData({
            abi: GetSenderAddressHelperAbi,
            bytecode: GetSenderAddressHelperByteCode,
            args: [entryPointAddress, formattedInitCode]
        })
    })

    if (!data) {
        throw new Error("Failed to get sender address")
    }

    return getAddress(data)
  }


export type EthereumProvider = { request(...args: any): Promise<any> }

export async function toOwner<provider extends EthereumProvider>({
    owner,
    address
}: {
    owner: OneOf<
        | provider
        | WalletClient<Transport, Chain | undefined, Account>
        | LocalAccount
    >
    address?: Address
}): Promise<LocalAccount> {
    if ("type" in owner && owner.type === "local") {
        return owner as LocalAccount
    }

    let walletClient:
        | WalletClient<Transport, Chain | undefined, Account>
        | undefined = undefined

    if ("request" in owner) {
        if (!address) {
            try {
                ;[address] = await (owner as EthereumProvider).request({
                    method: "eth_requestAccounts"
                })
            } catch {
                ;[address] = await (owner as EthereumProvider).request({
                    method: "eth_accounts"
                })
            }
        }
        if (!address) {
            // For TS to be happy
            throw new Error("address is required")
        }
        walletClient = createWalletClient({
            account: address,
            transport: custom(owner as EthereumProvider)
        })
    }

    if (!walletClient) {
        walletClient = owner as WalletClient<
            Transport,
            Chain | undefined,
            Account
        >
    }

    return toAccount({
        address: walletClient.account.address,
        async signMessage({ message }) {
            return walletClient.signMessage({ message })
        },
        async signTypedData(typedData) {
            return getAction(
                walletClient,
                signTypedData,
                "signTypedData"
            )(typedData as any)
        },
        async signTransaction(_) {
            throw new Error(
                "Smart account signer doesn't need to sign transactions"
            )
        }
    })
}