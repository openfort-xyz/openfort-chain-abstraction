// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InvoiceManager} from "../contracts/core/InvoiceManager.sol";

import {IInvoiceManager} from "../contracts/interfaces/IInvoiceManager.sol";
import {MockERC20} from "../contracts/mocks/MockERC20.sol";
import {CABPaymaster} from "../contracts/paymasters/CABPaymaster.sol";
import {CABPaymasterFactory} from "../contracts/paymasters/CABPaymasterFactory.sol";
import {Test, console} from "forge-std/Test.sol";

contract CABPaymasterFactoryTest is Test {
    CABPaymasterFactory public factory;
    address public owner;
    address public user;
    address public invoiceManager;
    address public verifyingSigner;
    MockERC20 public mockToken;

    function setUp() public {
        owner = makeAddr("OWNER");
        user = makeAddr("USER");
        invoiceManager = address(new InvoiceManager());
        verifyingSigner = makeAddr("VERIFYING_SIGNER");

        vm.startPrank(owner);
        factory = new CABPaymasterFactory(owner, invoiceManager, verifyingSigner);
        vm.stopPrank();

        mockToken = new MockERC20();
    }

    function testCreateCABPaymaster() public {
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(mockToken);

        bytes32 nonce = bytes32(uint256(1));

        // Predict address
        address predictedAddress = factory.getAddressWithNonce(user, nonce);

        // Create paymaster
        vm.prank(user);
        address paymaster = factory.createCABPaymaster(user, nonce, supportedTokens);

        // Verify prediction was correct
        assertEq(paymaster, predictedAddress, "Predicted address does not match actual address");

        // Verify paymaster properties
        CABPaymaster cabPaymaster = CABPaymaster(payable(paymaster));
        assertEq(cabPaymaster.owner(), user, "Paymaster owner should be user");
        address[] memory _supportedTokens = cabPaymaster.getSupportedTokens();
        bool isSupported = false;
        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            if (supportedTokens[i] == address(mockToken)) {
                isSupported = true;
                break;
            }
        }
        assertTrue(isSupported, "Token should be supported");
    }

    function testCannotCreatePaymasterWithFactoryOwner() public {
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(mockToken);

        bytes32 nonce = bytes32(uint256(1));

        vm.expectRevert("CABPaymasterFactory: Wrong owner");
        factory.createCABPaymaster(owner, nonce, supportedTokens);
    }

    function testCreateMultiplePaymasters() public {
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(mockToken);

        bytes32 nonce1 = bytes32(uint256(1));
        bytes32 nonce2 = bytes32(uint256(2));

        vm.startPrank(user);
        address paymaster1 = factory.createCABPaymaster(user, nonce1, supportedTokens);
        address paymaster2 = factory.createCABPaymaster(user, nonce2, supportedTokens);
        vm.stopPrank();

        assertNotEq(paymaster1, paymaster2, "Paymasters should have different addresses");
    }

    function testReturnExistingPaymaster() public {
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(mockToken);

        bytes32 nonce = bytes32(uint256(1));

        vm.prank(user);
        address paymaster1 = factory.createCABPaymaster(user, nonce, supportedTokens);

        vm.prank(user);
        address paymaster2 = factory.createCABPaymaster(user, nonce, supportedTokens);

        assertEq(paymaster1, paymaster2, "Should return existing paymaster");
    }

    function testUpdateInvoiceManager() public {
        address newInvoiceManager = makeAddr("NEW_INVOICE_MANAGER");

        vm.prank(owner);
        factory.updateInvoiceManager(newInvoiceManager);

        assertEq(factory.invoiceManager(), newInvoiceManager, "Invoice manager not updated");
    }

    function testUpdateVerifyingSigner() public {
        address newVerifyingSigner = makeAddr("NEW_VERIFYING_SIGNER");

        vm.prank(owner);
        factory.updateVerifyingSigner(newVerifyingSigner);

        assertEq(factory.verifyingSigner(), newVerifyingSigner, "Verifying signer not updated");
    }

    function testCannotUpdateInvoiceManagerAsNonOwner() public {
        address newInvoiceManager = makeAddr("NEW_INVOICE_MANAGER");

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        factory.updateInvoiceManager(newInvoiceManager);
    }

    function testCannotUpdateVerifyingSignerAsNonOwner() public {
        address newVerifyingSigner = makeAddr("NEW_VERIFYING_SIGNER");

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        factory.updateVerifyingSigner(newVerifyingSigner);
    }

    function testCannotSetZeroAddressAsInvoiceManager() public {
        vm.prank(owner);
        vm.expectRevert("Invoice manager cannot be the zero address");
        factory.updateInvoiceManager(address(0));
    }

    function testCannotSetZeroAddressAsVerifyingSigner() public {
        vm.prank(owner);
        vm.expectRevert("Verifying signer cannot be the zero address");
        factory.updateVerifyingSigner(address(0));
    }

    function testGetAddressWithNonce() public {
        bytes32 nonce = bytes32(uint256(1));
        address computedAddress = factory.getAddressWithNonce(user, nonce);

        // Ensure the computed address is not zero
        assertNotEq(computedAddress, address(0), "Computed address should not be zero");

        // Create the paymaster and verify the address matches
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(mockToken);

        vm.prank(user);
        address actualAddress = factory.createCABPaymaster(user, nonce, supportedTokens);

        assertEq(actualAddress, computedAddress, "Actual address should match computed address");
    }
}
