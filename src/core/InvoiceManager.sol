/*

,gggggggggggg,                                       
dP"""88""""""Y8b,                    ,dPYb,           
Yb,  88       `8b,                   IP'`Yb           
 `"  88        `8b  gg               I8  8I           
     88         Y8  ""               I8  8'           
     88         d8  gg     ,gggg,gg  I8 dP  gg     gg 
     88        ,8P  88    dP"  "Y8I  I8dP   I8     8I 
     88       ,8P'  88   i8'    ,8I  I8P    I8,   ,8I 
     88______,dP' _,88,_,d8,   ,d8b,,d8b,_ ,d8b, ,d8I 
    888888888P"   8P""Y8P"Y8888P"`Y88P'"Y88P""Y88P"888
                                                 ,d8I'
                                               ,dP'8I 
                                              ,8"  8I 
                                              I8   8I 
                                              `8, ,8I 
                                               `Y8P"  

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

    /// @notice Mapping: invoiceId => Invoice to store the invoice.
    mapping(bytes32 => Invoice) public invoices;

    /// @notice Mapping: invoiceId => bool to store the invoice repayment status.
    mapping(bytes32 => bool) public isInvoiceRepaid;

    /// @notice Mapping: smart account => CABPaymaster to store the CAB paymaster.
    mapping(address => CABPaymaster) public cabPaymasters;

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, IVaultManager _vaultManager) public virtual initializer {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();

        vaultManager = _vaultManager;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier onlyPaymaster(address account) {
        require(cabPaymasters[account].paymaster == msg.sender, "InvoiceManager: caller is not the paymaster");
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
        // check if the invoice already exists
        require(invoices[invoiceId].account == address(0), "InvoiceManager: invoice already exists");
        // store the invoice
        invoices[invoiceId] = Invoice(account, nonce, msg.sender, block.chainid);

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

        if (!isVerified) {
            revert("InvoiceManager: invalid invoice");
        }
        (IVault[] memory vaults, uint256[] memory amounts) = _getRepayToken(invoice);

        isInvoiceRepaid[invoiceId] = true;
        vaultManager.withdrawSponsorToken(invoice.account, vaults, amounts, invoice.paymaster);

        emit InvoiceRepaid(invoiceId, invoice.account, invoice.paymaster);
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
        return invoices[invoiceId];
    }

    /// @inheritdoc IInvoiceManager
    function getInvoiceId(
        address account,
        address paymaster,
        uint256 nonce,
        uint256 sponsorChainId,
        bytes calldata repayTokenInfos
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(account, paymaster, nonce, sponsorChainId, repayTokenInfos));
    }

    function _getRepayToken(InvoiceWithRepayTokens memory invoice) internal view returns (IVault[] memory, uint256[] memory) {
        IVault[] memory vaults = new IVault[](invoice.repayTokenInfos.length);
        uint256[] memory amounts = new uint256[](invoice.repayTokenInfos.length);
        uint256 count = 0;
        for (uint256 i = 0; i < invoice.repayTokenInfos.length; i++) {
            IInvoiceManager.RepayTokenInfo memory repayTokenInfo = invoice.repayTokenInfos[i];
            if (repayTokenInfo.chainId == block.chainid) {
                vaults[count] = repayTokenInfo.vault;
                amounts[count] = repayTokenInfo.amount;
                count++;
            }
        }
        assembly {
            mstore(vaults, count)
            mstore(amounts, count)
        }
        return (vaults, amounts);
    }
}
