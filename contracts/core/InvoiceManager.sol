/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@===%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    :%@@@@@@@@@@@@@@@@@@@@@@@@#  @@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  #@@@@@@@@@@@@@@@@@@@@@@@@@@@#  @@@@@@@@@@@@@@@
@@@@@@@@@@@@                     %@@@@@@@*        @@@@.         @@@@@*        @@@#         =@@@       *@@        *@@@@  +   -.       .@@@@@@@@@@@
@@@@@@@@@@@@  @@@@@@@@@@@@@@@@@  %@@@@@@:  @@@@@-  @@@.  #@@@@:  %@@   @@@@@:  @@#   @@@@+  +@@@@  #@@@%  :@@@@%  .@@@   *@@@@@#  @@@@@@@@@@@@@@@
@@@@@@@@@@@@  @@:           .@@  %@@@@@%  #@@@@@@   @@. -@@@@@@  .@@  +%%%%%%  *@#  @@@@@@.  @@@@  #@@@.  @@@@@@*  @@@  *@@@@@@#  @@@@@@@@@@@@@@@
@@@@@@@@@@@@  @@: .@@@@@@@. .@@  %@@@@@#  %@@@@@@.  @@. -@@@@@@.  @@  =********@@#  @@@@@@-  @@@@  #@@@  .@@@@@@#  %@@  #@@@@@@#  @@@@@@@@@@@@@@@
@@@@@@@@@@@@  @@: .@@%%@@@: .@@  %@@@@@@   @@@@@%  +@@.  @@@@@%  +@@  .@@@@@@*%@@#  @@@@@@-  @@@@  #@@@=  %@@@@@.  @@@  #@@@@@@%  @@@@@@@@@@@@@@@
@@@@@@@@@@@@  @@: .@@  -@@: .@@  %@@@@@@@    .    +@@@.    ..   =@@@@    .    *@@#  @@@@@@-  @@@@  #@@@@+    .    @@@@  #@@@@@@@    .-@@@@@@@@@@@
@@@@@@@@@@@@  @@- -@@: =@@= -@@  @@@@@@@@@@+:::-@@@@@@. .@-:::%@@@@@@@@*:::-@@@@@@-=@@@@@@*--@@@@--@@@@@@@@::::+@@@@@@+=@@@@@@@@@@-::+@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@. .@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@. .@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

contract InvoiceManager is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IInvoiceManager {
    IVaultManager public vaultManager;

    IPaymasterVerifier public fallbackPaymasterVerifier;

    /// @notice Settlememt storage location used as the base for the invoices mapping following EIP-7201.
    // keccak256(abi.encode(uint256(keccak256(bytes("Dialy"))) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SETTLEMENT_STORAGE_LOCATION = 0x1574f0d0c24265911bc4961cda61aadd6e06faacad4bf42a2f89fb53fed1c800;

    /// @notice Struct: group invoices under the same storage key to ease remote state proving. (eth_getProof)
    struct SettlementStorage {
        /// @notice Mapping: invoiceId => Invoice to store the invoice.
        mapping(bytes32 => Invoice) invoices;
    }

    /// @notice Mapping: invoiceId => bool to store the invoice repayment status.
    mapping(bytes32 => bool) public isInvoiceRepaid;

    /// @notice Mapping: smart account => CABPaymaster to store the CAB paymaster.
    mapping(address => CABPaymaster) public cabPaymasters;

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, IVaultManager _vaultManager, IPaymasterVerifier _fallbackPaymasterVerifier)
        public
        virtual
        initializer
    {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();

        vaultManager = _vaultManager;
        fallbackPaymasterVerifier = _fallbackPaymasterVerifier;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier onlyPaymaster(address account) {
        require(cabPaymasters[account].paymaster == msg.sender, "InvoiceManager: unauthorized paymaster");
        _;
    }

    /// @inheritdoc IInvoiceManager
    function registerPaymaster(address paymaster, IPaymasterVerifier paymasterVerifier, uint256 expiry) external override {
        require(expiry > block.timestamp, "InvoiceManager: invalid expiry");
        require(cabPaymasters[msg.sender].paymaster == address(0), "InvoiceManager: paymaster already registered");

        cabPaymasters[msg.sender] = CABPaymaster(paymaster, paymasterVerifier, expiry);

        emit PaymasterRegistered(msg.sender, paymaster, paymasterVerifier, expiry);
    }

    /// @inheritdoc IInvoiceManager
    function revokePaymaster() external override {
        CABPaymaster storage paymaster = cabPaymasters[msg.sender];
        require(paymaster.paymaster != address(0), "InvoiceManager: paymaster not registered");
        require(paymaster.expiry <= block.timestamp, "InvoiceManager: paymaster not expired");

        emit PaymasterRevoked(msg.sender, paymaster.paymaster, paymaster.paymasterVerifier);

        delete cabPaymasters[msg.sender];
    }

    /// @inheritdoc IInvoiceManager
    function createInvoice(uint256 nonce, address account, bytes32 invoiceId) external override onlyPaymaster(account) {
        SettlementStorage storage $ = _getSettlementStorage();
        // check if the invoice already exists
        require($.invoices[invoiceId].account == address(0), "InvoiceManager: invoice already exists");
        // store the invoice
        $.invoices[invoiceId] = Invoice(account, nonce, msg.sender, block.chainid);

        emit InvoiceCreated(invoiceId, account, msg.sender);
    }

    /// @inheritdoc IInvoiceManager
    function repay(bytes32 invoiceId, InvoiceWithRepayTokens calldata invoice, bytes calldata proof)
        external
        override
        nonReentrant
    {
        IPaymasterVerifier paymasterVerifier = cabPaymasters[invoice.account].paymasterVerifier;
        require(address(paymasterVerifier) != address(0), "InvoiceManager: paymaster verifier not registered");
        require(!isInvoiceRepaid[invoiceId], "InvoiceManager: invoice already repaid");

        bool isVerified = paymasterVerifier.verifyInvoice(invoiceId, invoice, proof);
        if (!isVerified) revert("InvoiceManager: invalid invoice");

        _repay(invoiceId, invoice);
    }

    /// @inheritdoc IInvoiceManager
    function fallbackRepay(bytes32 invoiceId, InvoiceWithRepayTokens calldata invoice, bytes calldata proof)
        external
        override
        nonReentrant
    {
        require(!isInvoiceRepaid[invoiceId], "InvoiceManager: invoice already repaid");

        bool isVerified = fallbackPaymasterVerifier.verifyInvoice(invoiceId, invoice, proof);
        if (!isVerified) revert("InvoiceManager: invalid invoice");

        _repay(invoiceId, invoice);
    }

    /// @inheritdoc IInvoiceManager
    function withdrawToAccount(address account, IVault[] calldata repayTokenVaults, uint256[] calldata repayAmounts)
        external
        override
        nonReentrant
    {
        address paymaster = cabPaymasters[account].paymaster;
        require(paymaster == msg.sender, "InvoiceManager: caller is not the paymaster");

        vaultManager.withdrawSponsorToken(account, repayTokenVaults, repayAmounts, account);
    }

    /// @inheritdoc IInvoiceManager
    function getCABPaymaster(address account) external view returns (CABPaymaster memory) {
        return cabPaymasters[account];
    }

    /// @inheritdoc IInvoiceManager
    function getInvoice(bytes32 invoiceId) external view returns (Invoice memory) {
        SettlementStorage storage $ = _getSettlementStorage();
        return $.invoices[invoiceId];
    }

    /// @inheritdoc IInvoiceManager
    function getInvoiceId(
        address account,
        address paymaster,
        uint256 nonce,
        uint256 sponsorChainId,
        bytes calldata repayTokenInfos
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, paymaster, nonce, sponsorChainId, repayTokenInfos));
    }

    function _getRepayToken(InvoiceWithRepayTokens memory invoice) internal view returns (IVault[] memory, uint256[] memory) {
        IVault[] memory vaults = new IVault[](invoice.repayTokenInfos.length);
        uint256[] memory amounts = new uint256[](invoice.repayTokenInfos.length);
        uint256 count = 0;
        for (uint256 i = 0; i < invoice.repayTokenInfos.length;) {
            IInvoiceManager.RepayTokenInfo memory repayTokenInfo = invoice.repayTokenInfos[i];
            if (repayTokenInfo.chainId == block.chainid) {
                vaults[count] = repayTokenInfo.vault;
                amounts[count] = repayTokenInfo.amount;
                unchecked {
                    ++count;
                }
            }
            unchecked {
                ++i;
            }
        }
        assembly {
            mstore(vaults, count)
            mstore(amounts, count)
        }
        return (vaults, amounts);
    }

    function _getSettlementStorage() private pure returns (SettlementStorage storage $) {
        assembly {
            $.slot := SETTLEMENT_STORAGE_LOCATION
        }
    }

    function _repay(bytes32 invoiceId, InvoiceWithRepayTokens calldata invoice) internal {
        (IVault[] memory vaults, uint256[] memory amounts) = _getRepayToken(invoice);

        isInvoiceRepaid[invoiceId] = true;
        vaultManager.withdrawSponsorToken(invoice.account, vaults, amounts, invoice.paymaster);

        emit InvoiceRepaid(invoiceId, invoice.account, invoice.paymaster);
    }
}
