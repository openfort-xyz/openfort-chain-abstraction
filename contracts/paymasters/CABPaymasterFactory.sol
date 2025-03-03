// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {CABPaymaster} from "./CABPaymaster.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import "account-abstraction/core/BasePaymaster.sol";

contract CABPaymasterFactory is Ownable {
    address public invoiceManager;
    address public verifyingSigner;

    event CABPaymasterCreated(address indexed owner, address indexed cabPaymaster);

    event InvoiceManagerUpdated(address indexed newInvoiceManager);
    event VerifyingSignerUpdated(address indexed newVerifyingSigner);

    constructor(address _owner, address _invoiceManager, address _verifyingSigner) Ownable(_owner) {
        invoiceManager = _invoiceManager;
        verifyingSigner = _verifyingSigner;
    }

    /*
     * @notice Create a CABPaymaster with the given _owner and _salt.
     * @param _owner The owner of the CABPaymaster.
     * @param _nonce The nonce for the CABPaymaster.
     * @return cabPaymaster The address of the CABPaymaster.
     */
    function createCABPaymaster(address _owner, bytes32 _nonce, address[] memory _supportedTokens)
        external
        returns (address cabPaymaster)
    {
        require(_owner != owner(), "CABPaymasterFactory: Wrong owner");
        bytes32 salt = keccak256(abi.encode(_owner, _nonce));
        cabPaymaster = getAddressWithNonce(_owner, _nonce);
        if (cabPaymaster.code.length > 0) return cabPaymaster;
        cabPaymaster = address(new CABPaymaster{salt: salt}(IInvoiceManager(invoiceManager), verifyingSigner, _owner));

        CABPaymaster(payable(cabPaymaster)).initialize(_supportedTokens);
        emit CABPaymasterCreated(_owner, cabPaymaster);
    }

    /*
     * @notice Return the address of a CABPaymaster that would be deployed with the given _salt.
     */
    function getAddressWithNonce(address _owner, bytes32 _nonce) public view returns (address) {
        bytes32 salt = keccak256(abi.encode(_owner, _nonce));
        return Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(CABPaymaster).creationCode, abi.encode(invoiceManager, verifyingSigner, _owner)))
        );
    }

    /*
     * @notice Update the invoice manager.
     * @param _invoiceManager The new invoice manager.
     */
    function updateInvoiceManager(address _invoiceManager) public onlyOwner {
        require(_invoiceManager != address(0), "Invoice manager cannot be the zero address");
        invoiceManager = _invoiceManager;
        emit InvoiceManagerUpdated(_invoiceManager);
    }

    /*
     * @notice Update the verifying signer.
     * @param _verifyingSigner The new verifying signer.
     */
    function updateVerifyingSigner(address _verifyingSigner) public onlyOwner {
        require(_verifyingSigner != address(0), "Verifying signer cannot be the zero address");
        verifyingSigner = _verifyingSigner;
        emit VerifyingSignerUpdated(_verifyingSigner);
    }
}
