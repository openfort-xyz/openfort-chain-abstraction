# Openfort Ecosystem Abstraction

## Overview
Ecosystems are parent entities for groups of apps operating on different blockchains or standalone layer 2 networks. Openfort [**ecosystem wallets**](https://www.openfort.xyz/docs/guides/ecosystem) enable seamless interoperability between applications, allowing ecosystems to design their ideal, unified wallet experience. The next evolution is consolidating user liquidity across blockchains, providing a single, unified balance instantly spendable throughout the ecosystem. This vision will be powered by Openfort's chain abstraction implementation of [MagicSpend++](https://ethresear.ch/t/magicspend-spend-now-debit-later/19678/9) hosted in this repository.

With this setup, ecosystems can deploy tailor-made 4337 chain abstraction infrastructure.
They become Liquidity Providers (LPs) for their users, sharing with them the value that would otherwise have been captured by solvers/fillers.
They own their users' experience from the wallet to the chain.


## System Architecture

![architecture](./assets/archi.jpg)

## Zoom on userOp paymasterAndData

![paymasterAndData](./assets/paymasterAndData.png)

## System Components

### Time-locked Vault
- Tokenized Vaults with a single underlying EIP-20 token
- *Not* [4626](https://eips.ethereum.org/EIPS/eip-4626) compliant (does *not* implement EIP-20 to represent shares)
- Only the VaultManager can interact with the Vault
- Define locking period when initializing the Vault
- Deploy on any supported source chains
- Can be yield-bearing (e.g deposit to Aave or Morpho)

_Note:_ "Locking" can be simplified into a *SEND* transaction from an EOA to the Smart Contract Account. A backend watcher listens for received events and automatically transfers the funds to a time-locked vault. This process requires users to sign a session key for the watcher service.

### Vault Manager
- Manage Vaults
- Manage withdrawals and deposits

### Invoice Manager
- Settlement of invoices
- Prevent double-repayment of invoices with state proof verification
- authorize paymasters and paymaster verifiers

### Chain Abstraction Paymaster (CABPaymaster)

The CABPaymaster fronts funds on the destination chain for the user if they _HAVE_ enough locked balance (checked by Openfort Backend).

The Paymaster contract will get repaid on the source chain(s). Ni1o: user has 100@A, 50@B, and spends 130@C

- Set/update the Paymaster owner address (ecosystem *MUST* own the Paymaster)
- Withdraw Paymaster balance (Openfort crafts the transaction, but the ecosystem owner *MUST* sign it)
- Ragequit > owner withdraw all funds from all Paymasters with one signature

Paymaster Owner can subscribe to webhook alerts when the Paymaster balance falls below a certain threshold, before automatic rebalancing is implemented.

### Paymaster Verifiers
- Permissionless verification of remote event (`InvoiceCreated`) or storage proof (`invoices` mapping in the invoiceManager)
- Permissionless verification of invoice

As part of chain abstraction activation, an account registers a Paymaster Verifier, which is subsequently called by the InvoiceManager before processing repayments.

One of the system's key strengths is its modular approach to proof verification. State proofs will play a crucial role in Ethereum interoperability, with more proof providers emerging. The design allows for seamless integration of new proof verification strategies, giving advanced users the flexibility to choose the one that best suits their use case.

## Trust assumptions

- The system relies on cross-L2 execution proofs currently provided by [Polymer](https://docs.polymerlabs.org/docs/build/examples/chain_abstraction/). This eliminates the need for Users to trust Openfort or the Ecosystem. To repay the ecosystem on the source chain(s) from the user assets locked in the vault(s), Openfort must prove the execution of the userOp on the destination chain. There is no refund on source chain without the corresponding remote chain execution proof. The `InvoiceManager` tracks invoices onchain to prevent double-refund.
- The system supports [Hashi](https://crosschain-alliance.gitbook.io/hashi/introduction/what-is-hashi) as a fallback proving mechanism if Polymer or Openfort cease operations. Liquidity providers (LPs) can generate a proof for their fronted funds by running a [Hashi RPC API locally](https://github.com/gnosis/hashi/tree/main/packages/rpc#getting-started) and call the `fallbackRepay` function of the `InvoiceManager` with the proof and the invoice. This enables refunds using only public data, without relying on any third party. The fallback proving strategy may evolve, but it will always remain permissionless, as it ultimately determines the system's security.
- Openfort does not have custody of funds in the Ecosystem Paymaster, as the userOp is co-signed within a secure enclave that enforces predefined policies set by the ecosystem. At any time, the ecosystem can disable a signer, immediately preventing any new userOp from being sent.

## Deployments

- One `InvoiceManager` owned by Openfort
- One `VaultManager` owned by Openfort
- One `CABPaymaster` per Ecosystem and Owned by the Ecosystem
- All vaults owned by Openfort
- All `Paymaster Verifiers`

Check latest deployments in the [demo cli](demo/constants.ts).
