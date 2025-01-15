// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {VaultManager} from "../../src/vaults/VaultManager.sol";
import {AaveVault} from "../../src/vaults/AaveVault.sol";
import {MockAavePool} from "../../src/mocks/MockAavePool.sol";
import {MockL2AavePool} from "../../src/mocks/MockL2AavePool.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockL2Encoder} from "../../src/mocks/MockL2Encoder.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DepositTest is Test {
    MockERC20 public mockUnderlyingToken;
    MockERC20 public mockAToken;
    MockAavePool public mockAavePool;
    MockL2AavePool public mockL2AavePool;
    MockL2Encoder public mockL2Encoder;
    VaultManager public vaultManager;
    AaveVault public aaveVaultL1;
    AaveVault public aaveVaultL2;

    address public alice = address(0x1);

    function setUp() public {
        // Deploy mocks
        mockUnderlyingToken = new MockERC20();
        mockAToken = new MockERC20();
        mockAavePool = new MockAavePool();
        mockL2AavePool = new MockL2AavePool();
        mockL2Encoder = new MockL2Encoder(address(mockL2AavePool));

        mockAavePool.addReserve(address(mockUnderlyingToken), address(mockAToken));
        mockL2AavePool.addReserve(address(mockUnderlyingToken), address(mockAToken));

        // Deploy VaultManager and AaveVault
        vaultManager = _deployVaultManager();
        aaveVaultL1 = _deployAaveVault(false, address(mockAavePool), address(0)); // L1 version
        aaveVaultL2 = _deployAaveVault(true, address(mockL2AavePool), address(mockL2Encoder)); // L2 version

        // Register AaveVault in VaultManager
        vaultManager.addVault(aaveVaultL1);
        vaultManager.addVault(aaveVaultL2);

        // Mint tokens for Alice
        mockUnderlyingToken.mint(alice, 1_000 ether);
        mockAToken.mint(address(mockAavePool), 10_000 ether);
        mockAToken.mint(address(mockL2AavePool), 10_000 ether);
    }

    function _deployVaultManager() internal returns (VaultManager) {
        VaultManager vaultManagerImplementation = new VaultManager();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(vaultManagerImplementation),
            abi.encodeWithSelector(VaultManager.initialize.selector, address(this), address(0), 0)
        );
        return VaultManager(address(proxy));
    }

    function _deployAaveVault(bool isL2, address pool, address l2Encoder) internal returns (AaveVault) {
        AaveVault aaveVaultImplementation = new AaveVault();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(aaveVaultImplementation),
            abi.encodeWithSelector(
                AaveVault.initialize.selector,
                address(vaultManager),
                address(mockUnderlyingToken),
                address(mockAToken),
                pool,
                isL2,
                l2Encoder
            )
        );
        return AaveVault(address(proxy));
    }

    function testDepositL1() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(alice);
        mockUnderlyingToken.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(mockUnderlyingToken, aaveVaultL1, depositAmount, false);
        vm.stopPrank();

        // Check balances and shares
        assertEq(mockAToken.balanceOf(address(aaveVaultL1)), depositAmount, "AToken balance mismatch");
        assertEq(mockUnderlyingToken.balanceOf(address(mockAavePool)), depositAmount, "Pool balance mismatch");
        assertEq(mockUnderlyingToken.balanceOf(address(aaveVaultL1)), 0, "Vault balance mismatch");
        assertEq(
            vaultManager.vaultShares(alice, aaveVaultL1), aaveVaultL1.underlyingToShares(depositAmount), "Shares mismatch"
        );
    }

    function testDepositL2() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(alice);
        mockUnderlyingToken.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(mockUnderlyingToken, aaveVaultL2, depositAmount, true);
        vm.stopPrank();

        assertEq(mockAToken.balanceOf(address(aaveVaultL2)), depositAmount, "AToken balance mismatch");
        assertEq(mockUnderlyingToken.balanceOf(address(mockL2AavePool)), depositAmount, "Pool balance mismatch");
        assertEq(mockUnderlyingToken.balanceOf(address(aaveVaultL1)), 0, "Vault balance mismatch");
        // Verify shares
        assertEq(vaultManager.vaultShares(alice, aaveVaultL2), aaveVaultL2.underlyingToShares(depositAmount), "Shares mismatch");
    }

    function testDepositFailsWithoutApproval() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(alice);
        vm.expectRevert();
        vaultManager.deposit(mockUnderlyingToken, aaveVaultL1, depositAmount, false);
        vm.stopPrank();
    }

    function testDepositFailsWithInvalidVault() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(alice);
        mockUnderlyingToken.approve(address(vaultManager), depositAmount);

        vm.expectRevert("VaultManager: vault not registered");
        vaultManager.deposit(mockUnderlyingToken, IVault(address(0)), depositAmount, false);
        vm.stopPrank();
    }
}
