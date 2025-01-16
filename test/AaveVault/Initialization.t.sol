// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IVaultManager} from "../../src/interfaces/IVaultManager.sol";
import {VaultManager} from "../../src/vaults/VaultManager.sol";
import {AaveVault} from "../../src/vaults/AaveVault.sol";
import {MockAavePool} from "../../src/mocks/MockAavePool.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockL2Encoder} from "../../src/mocks/MockL2Encoder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract InitializationTest is Test {
    AaveVault public vault;
    AaveVault public vaultImplementation;
    MockAavePool public mockAavePool;
    MockERC20 public mockUnderlyingToken;
    MockERC20 public mockAToken;
    VaultManager public mockVaultManager;
    MockL2Encoder public mockL2Encoder;
    ERC1967Proxy public proxy;

    function setUp() public {
        // Deploy mock contracts
        mockUnderlyingToken = new MockERC20();
        mockAToken = new MockERC20();
        mockAavePool = new MockAavePool();
        mockVaultManager = new VaultManager();
        mockL2Encoder = new MockL2Encoder(address(mockAavePool));

        // Deploy the AaveVault implementation
        vaultImplementation = new AaveVault();
    }

    function testInitializationL1() public {
        // Deploy the proxy and initialize for L1
        proxy = new ERC1967Proxy(
            address(vaultImplementation),
            abi.encodeWithSelector(
                AaveVault.initialize.selector,
                address(mockVaultManager),
                address(mockUnderlyingToken),
                address(mockAToken),
                address(mockAavePool),
                false, // isL2
                address(0) // No L2Encoder for L1
            )
        );

        // Cast proxy as AaveVault
        vault = AaveVault(address(proxy));

        // Assertions to confirm initialization succeeded
        assertEq(address(vault.aavePool()), address(mockAavePool), "Aave Pool not set correctly");
        assertEq(address(vault.aToken()), address(mockAToken), "aToken not set correctly");
        assertEq(address(vault.underlyingToken()), address(mockUnderlyingToken), "Underlying token not set correctly");
        assertEq(vault.isL2(), false, "isL2 flag not set correctly");

        // Check that the allowance was set correctly
        uint256 allowance = mockUnderlyingToken.allowance(address(vault), address(mockAavePool));
        assertEq(allowance, type(uint256).max, "Allowance for Aave Pool not set correctly");
    }

    function testInitializationL2() public {
        // Deploy the proxy and initialize for L2
        proxy = new ERC1967Proxy(
            address(vaultImplementation),
            abi.encodeWithSelector(
                AaveVault.initialize.selector,
                address(mockVaultManager),
                address(mockUnderlyingToken),
                address(mockAToken),
                address(mockAavePool),
                true, // isL2
                address(mockL2Encoder)
            )
        );

        // Cast proxy as AaveVault
        vault = AaveVault(address(proxy));

        // Assertions to confirm initialization succeeded
        assertEq(address(vault.aavePool()), address(mockAavePool), "Aave Pool not set correctly");
        assertEq(address(vault.aToken()), address(mockAToken), "aToken not set correctly");
        assertEq(address(vault.underlyingToken()), address(mockUnderlyingToken), "Underlying token not set correctly");
        assertEq(address(vault.l2Encoder()), address(mockL2Encoder), "L2Encoder not set correctly");
        assertEq(vault.isL2(), true, "isL2 flag not set correctly");

        // Check that the allowance was set correctly
        uint256 allowance = mockUnderlyingToken.allowance(address(vault), address(mockAavePool));
        assertEq(allowance, type(uint256).max, "Allowance for Aave Pool not set correctly");
    }

    function testInitializationRevertsInvalidL2Encoder() public {
        vm.expectRevert("Vault: Invalid L2 Encoder");
        proxy = new ERC1967Proxy(
            address(vaultImplementation),
            abi.encodeWithSelector(
                AaveVault.initialize.selector,
                address(mockVaultManager),
                address(mockUnderlyingToken),
                address(mockAToken),
                address(mockAavePool),
                true, // isL2
                address(0) // Invalid L2Encoder
            )
        );
    }

    function testInitializationRevertsInvalidVaultManager() public {
        vm.expectRevert("Vault: Invalid Vault Manager");
        proxy = new ERC1967Proxy(
            address(vaultImplementation),
            abi.encodeWithSelector(
                AaveVault.initialize.selector,
                address(0), // Invalid Vault Manager
                address(mockUnderlyingToken),
                address(mockAToken),
                address(mockAavePool),
                false, // isL2
                address(0)
            )
        );
    }

    function testInitializationRevertsInvalidAavePool() public {
        vm.expectRevert("Vault: Invalid Aave Pool");
        proxy = new ERC1967Proxy(
            address(vaultImplementation),
            abi.encodeWithSelector(
                AaveVault.initialize.selector,
                address(mockVaultManager),
                address(mockUnderlyingToken),
                address(mockAToken),
                address(0), // Invalid Aave Pool
                false, // isL2
                address(0)
            )
        );
    }

    function testInitializationRevertsInvalidUnderlyingToken() public {
        vm.expectRevert("Vault: Invalid underlying token");
        proxy = new ERC1967Proxy(
            address(vaultImplementation),
            abi.encodeWithSelector(
                AaveVault.initialize.selector,
                address(mockVaultManager),
                address(0), // Invalid Underlying Token
                address(mockAToken),
                address(mockAavePool),
                false, // isL2
                address(0)
            )
        );
    }

    function testInitializationRevertsInvalidAToken() public {
        vm.expectRevert("Vault: Invalid aToken");
        proxy = new ERC1967Proxy(
            address(vaultImplementation),
            abi.encodeWithSelector(
                AaveVault.initialize.selector,
                address(mockVaultManager),
                address(mockUnderlyingToken),
                address(0), // Invalid aToken
                address(mockAavePool),
                false, // isL2
                address(0)
            )
        );
    }
}
