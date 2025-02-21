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

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {LibEncoders} from "../libraries/LibEncoders.sol";
import {HashiProverLib} from "@hashi/prover/HashiProverLib.sol";

import {RLPReader} from "@eth-optimism/contracts-bedrock/src/libraries/rlp/RLPReader.sol";
import {ReceiptProof} from "@hashi/prover/HashiProverStructs.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title HashiPaymasterVerifier
 * @notice A contract that can verify invoices emitted on remote chains.
 */
contract HashiPaymasterVerifier is IPaymasterVerifier, Ownable {
    using LibEncoders for IInvoiceManager.RepayTokenInfo[];
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

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

        bytes memory topics = logFields[1].readBytes();

        assembly {
            let topic0 := mload(add(topics, 0x20))
            let topic1 := mload(add(topics, 0x40))
            // IInvoiceManager.InvoiceCreated.selector
            let selector := 0x5243d6c5479d93025de9e138a29c467868f762bb78591e96299fb3f437afcc04
            success := and(eq(topic0, selector), eq(topic1, invoiceId))
        }
    }
}
