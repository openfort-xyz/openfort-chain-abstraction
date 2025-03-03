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

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../../interfaces/IInvoiceManager.sol";
import {IPaymasterVerifier} from "../../interfaces/IPaymasterVerifier.sol";
import {LibEncoders} from "../../libraries/LibEncoders.sol";
import {HashiProverLib} from "@hashi/prover/HashiProverLib.sol";

import {RLPReader} from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import {ReceiptProof} from "@hashi/prover/HashiProverStructs.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {LibBytes} from "@solady/utils/LibBytes.sol";

/**
 * @title HashiPaymasterVerifier
 * @notice A contract that can verify invoices emitted on remote chains.
 */
contract HashiPaymasterVerifier is IPaymasterVerifier, Ownable {
    using LibEncoders for IInvoiceManager.RepayTokenInfo[];
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using LibBytes for bytes;

    IInvoiceManager public immutable invoiceManager;
    address public immutable shoyuBashi;

    constructor(IInvoiceManager _invoiceManager, address _shoyuBashi, address _owner) Ownable(_owner) {
        invoiceManager = _invoiceManager;
        shoyuBashi = _shoyuBashi;
    }

    /// @inheritdoc IPaymasterVerifier
    function verifyInvoice(bytes32 _invoiceId, IInvoiceManager.InvoiceWithRepayTokens calldata _invoice, bytes calldata _proof)
        external
        virtual
        override
        returns (bool success)
    {
        bytes32 invoiceId = invoiceManager.getInvoiceId(
            _invoice.account, _invoice.paymaster, _invoice.nonce, _invoice.sponsorChainId, _invoice.repayTokenInfos.encode()
        );

        if (invoiceId != _invoiceId) return false;

        ReceiptProof calldata proof;

        assembly {
            proof := add(_proof.offset, 0x20)
        }

        bytes memory logs = HashiProverLib.verifyForeignEvent(proof, shoyuBashi);
        RLPReader.RLPItem[] memory logFields = logs.toRLPItem().readList();

        if (logFields.length != 3) revert("Hashi: InvalidLogFormat");

        address emitter = address(bytes20(logFields[0].readBytes()));

        if (emitter != address(invoiceManager)) return false;

        RLPReader.RLPItem[] memory topics = logFields[1].readList();

        bytes memory topic0 = topics[0].readBytes();
        bytes memory topic1 = topics[1].readBytes();

        success = topic0.eqs(IInvoiceManager.InvoiceCreated.selector) && topic1.eqs(invoiceId);
    }
}
