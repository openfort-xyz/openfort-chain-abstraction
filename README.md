# Openfort Ecosystem Abstraction

## Overview
Ecosystems are parent entities for groups of apps operating across different blockchains or standalone layer 2 networks. Openfort [**ecosystem wallets**](https://www.openfort.xyz/docs/guides/ecosystem) enable seamless interoperability between applications, allowing ecosystems to design their ideal, unified wallet experience. The next evolution is consolidating user liquidity across apps, providing a single, unified balance instantly spendable across the ecosystem. This vision will be powered by Openfort's chain abstraction implementation based on [MagicSpend++](https://ethresear.ch/t/magicspend-spend-now-debit-later/19678/9) hosted in this repository.

With this setup, ecosystems can deploy tailor-made 4337 chain abstraction infrastructure.
They become Liquidity Providers (LPs) for their users, sharing with them the value that would otherwise have been captured by solvers/fillers.
They own their users' experience from the wallet to the chain.


You will find *at least* the following contracts:

* Chain Abstraction Paymaster
* Time-locked Vault
* Vault Manager
* Invoice Manager

## System Architecture

![architecture](./assets/archi.jpg)

## Zoom on userOp paymasterAndData

![paymasterAndData](./assets/paymasterAndData.png)

## System Components & assumptions

### Time-locked Vault
- Define locking period
- Deploy on any chain
- Define any ERC20 / native asset (each asset must have a correspondence in dollars)
- Define the yield strategy

_Note:_ "locking" can be simplified into a **SEND** transaction from an EOA to the Smart Contract Account. A backend watcher service could listen for `received` events and automatically lock the funds (i.e., transfer them to the time-locked vault). This approach would require users to sign a session key for the watcher service.


### Chain Abstraction Paymaster

The Paymaster fronts the funds on the destination chain for the user if they _HAVE_ enough locked balance (checked by Openfort Backend).
The Paymaster contract will then be reimbursed on the source chain(s). Ni1o: user has 100@A, 50@B, and spends 130@C

* Set/update the Paymaster owner address (ecosystem *MUST* own the Paymaster).
* Fund/withdraw Paymaster balance (Openfort crafts the transaction, but the ecosystem owner _MUST_ sign it).
* Ragequit > withdraw all funds from all Paymasters
* Receive webhook alerts when the Paymaster balance falls below a certain threshold to enable rebalancing.

### Trust assumptions

* The system relies on cross-L2 execution proofs enabled by [Polymer](https://www.polymerlabs.org/), eliminating the need for Users to trust Openfort or the Ecosystem. To recover funds locked in source chain vaults on behalf of the ecosystem, Openfort must prove the execution of the userOp on the remote chain. There is no refund on source chain without the corresponding remote chain execution proof. The InvoiceManager track invoices onchain to prevent double-refund.
* Openfort does not have custody of funds in the Ecosystem Paymaster because the userOp is co-signed within a secure enclave, following predefined policies set by the ecosystem.


### Onchain deployments

One time action by Openfort: Deploy Vaults, VaultManager and InvoiceManager.

->> LP as a Service: Deploy the Chain Abstraction Paymaster *on each* blockchain supported by the ecosystem.


# Local Development


Launch tests:
```
forge test
```

Deploy local node:
```
anvil
```

Deploy two mock ERC20:

```
forge create src/mocks/MockERC20.sol:MockERC20 --private-key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge create src/mocks/MockERC20.sol:MockERC20 --private-key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```


Deploy Chain Abstraction Setup including Invoice Manager, two tokenized vaults, Vault Manager and Paymaster:
```
PK_DEPLOYER=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
CROSS_L2_PROVER=0xBA3647D0749Cb37CD92Cc98e6185A77a8DCBFC62
OWNER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
WITHDRAW_LOCK_BLOCK=100
VERIFYING_SIGNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
VERSION_SALT=0x6660000000000000000000000000000000000000000000000000000000000000
ENTRY_POINT_ADDRESS=0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
forge script script/deployChainAbstractionSetup.s.sol:DeployChainAbstractionSetup "[0xusdc, 0xusdt]" --sig "run(address[])" --rpc-url=127.0.0.1:854
```