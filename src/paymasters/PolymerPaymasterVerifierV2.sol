// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";

/**
 * @title ICrossL2Prover
 * @author Polymer Labs
 * @notice A contract that can prove peptides state. Since peptide is an aggregator of many chains' states, this
 * contract can in turn be used to prove any arbitrary events and/or storage on counterparty chains.
 */
interface ICrossL2ProverV2 {
    /**
     * @notice A a log at a given raw rlp encoded receipt at a given logIndex within the receipt.
     * @notice the receiptRLP should first be validated by calling validateReceipt.
     * @param proof: The proof of a given rlp bytes for the receipt, returned from the receipt MMPT of a block.
     * @return chainId The chainID that the proof proves the log for
     * @return emittingContract The address of the contract that emitted the log on the source chain
     * @return topics The topics of the event. First topic is the event signature that can be calculated by
     * Event.selector. The remaining elements in this array are the indexed parameters of the event.
     * @return unindexedData // The abi encoded non-indexed parameters of the event.
     */
    function validateEvent(bytes calldata proof)
        external
        view
        returns (uint32 chainId, address emittingContract, bytes calldata topics, bytes calldata unindexedData);
}

/**
 * @title PolymerPaymasterVerifierV2
 * @notice A contract that can verify invoices emitted on remote chains.
 */
contract PolymerPaymasterVerifierV2 is IPaymasterVerifier, Ownable {
    IInvoiceManager public immutable invoiceManager;
    ICrossL2ProverV2 public immutable crossL2Prover;

    constructor(IInvoiceManager _invoiceManager, ICrossL2ProverV2 _crossL2Prover, address _owner) Ownable(_owner) {
        invoiceManager = _invoiceManager;
        crossL2Prover = _crossL2Prover;
    }

    /// @inheritdoc IPaymasterVerifier
    function verifyInvoice(
        bytes32 _invoiceId,
        IInvoiceManager.InvoiceWithRepayTokens calldata _invoice,
        bytes calldata _proof
    ) external virtual override returns (bool success) {
        bytes32 invoiceId = invoiceManager.getInvoiceId(
            _invoice.account,
            _invoice.paymaster,
            _invoice.nonce,
            _invoice.sponsorChainId,
            _encodeRepayToken(_invoice.repayTokenInfos)
        );

        if (invoiceId != _invoiceId) return false;
        (,, bytes memory topics,) = crossL2Prover.validateEvent(_proof);

        assembly {
            let topic0 := mload(add(topics, 0x20))
            let topic1 := mload(add(topics, 0x40))
            // IInvoiceManager.InvoiceCreated.selector
            let selector := 0x5243d6c5479d93025de9e138a29c467868f762bb78591e96299fb3f437afcc04
            success := and(eq(topic0, selector), eq(topic1, invoiceId))
        }
    }

    function _encodeRepayToken(IInvoiceManager.RepayTokenInfo[] memory repayTokens)
        internal
        pure
        returns (bytes memory encodedRepayToken)
    {
        for (uint8 i = 0; i < repayTokens.length; i++) {
            encodedRepayToken = bytes.concat(
                encodedRepayToken,
                bytes20(address(repayTokens[i].vault)),
                bytes32(repayTokens[i].amount),
                bytes32(repayTokens[i].chainId)
            );
        }
        return abi.encodePacked(uint8(repayTokens.length), encodedRepayToken);
    }
}
