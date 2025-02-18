// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LibBytes} from "@solady/utils/LibBytes.sol";
import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";
import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {LibEncoders} from "../libraries/LibEncoders.sol";

contract PolymerPaymasterVerifierV1 is IPaymasterVerifier, Ownable {
    using LibBytes for bytes;
    using LibEncoders for IInvoiceManager.RepayTokenInfo[];

    IInvoiceManager public immutable invoiceManager;
    ICrossL2Prover public immutable crossL2Prover;

    constructor(IInvoiceManager _invoiceManager, ICrossL2Prover _crossL2Prover, address _owner) Ownable(_owner) {
        invoiceManager = _invoiceManager;
        crossL2Prover = _crossL2Prover;
    }

    /// @inheritdoc IPaymasterVerifier
    function verifyInvoice(
        bytes32 _invoiceId,
        IInvoiceManager.InvoiceWithRepayTokens calldata _invoice,
        bytes calldata _proof
    ) external virtual override returns (bool) {
        bytes32 invoiceId = invoiceManager.getInvoiceId(
            _invoice.account,
            _invoice.paymaster,
            _invoice.nonce,
            _invoice.sponsorChainId,
            _invoice.repayTokenInfos.encode()
        );

        if (invoiceId != _invoiceId) return false;

        (uint256 logIndex, bytes memory proof) = abi.decode(_proof, (uint256, bytes));
        (,, bytes[] memory topics,) = crossL2Prover.validateEvent(logIndex, proof);

        return topics[0].eqs(IInvoiceManager.InvoiceCreated.selector) && topics[1].eqs(invoiceId);
    }
}
