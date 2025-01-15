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

contract WithdrawTest is Test {
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

        // Simulate deposit by Alice
        vm.startPrank(alice);
        mockUnderlyingToken.approve(address(vaultManager), 200 ether);
        vaultManager.deposit(mockUnderlyingToken, aaveVaultL1, 100 ether, false); // L1 deposit
        vaultManager.deposit(mockUnderlyingToken, aaveVaultL2, 100 ether, true); // L2 deposit
        vm.stopPrank();
    }

    function _deployVaultManager() internal returns (VaultManager) {
        VaultManager vaultManagerImplementation = new VaultManager();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(vaultManagerImplementation),
            abi.encodeWithSelector(VaultManager.initialize.selector, address(this), address(0), 1) // 1 блок для lock периода
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

    function testQueueAndCompleteWithdrawL1() public {
        uint256 withdrawAmount = 100 ether;

        // Convert to shares
        uint256 sharesWithdrawAmount = aaveVaultL1.underlyingToShares(withdrawAmount);

        IVault[] memory vaults = new IVault[](1);
        vaults[0] = aaveVaultL1;

        uint256[] memory sharesToWithdraw = new uint256[](1);
        sharesToWithdraw[0] = sharesWithdrawAmount;

        vm.startPrank(alice);
        bytes32 withdrawalId = vaultManager.queueWithdrawals(vaults, sharesToWithdraw, alice);
        vm.stopPrank();

        // Simulate passing lock period
        vm.roll(block.number + 2);

        // Complete withdrawal
        bytes32[] memory withdrawalIds = new bytes32[](1);
        withdrawalIds[0] = withdrawalId;

        vm.startPrank(alice);
        vaultManager.completeWithdrawals(withdrawalIds);
        vm.stopPrank();

        // Verify balances
        assertEq(mockUnderlyingToken.balanceOf(alice), 900 ether, "Alice did not receive correct L1 withdrawal amount");
        assertEq(vaultManager.vaultShares(alice, aaveVaultL1), aaveVaultL1.totalShares() - sharesWithdrawAmount, "Shares mismatch after L1 withdrawal");
    }

    function testQueueAndCompleteWithdrawL2() public {
        uint256 withdrawAmount = 100 ether;

        // Convert to shares
        uint256 sharesWithdrawAmount = aaveVaultL2.underlyingToShares(withdrawAmount);

        // Queue withdrawal
        IVault[] memory vaults = new IVault[](1);
        vaults[0] = aaveVaultL2;

        uint256[] memory sharesToWithdraw = new uint256[](1);
        sharesToWithdraw[0] = sharesWithdrawAmount;

        vm.startPrank(alice);
        bytes32 withdrawalId = vaultManager.queueWithdrawals(vaults, sharesToWithdraw, alice);
        vm.stopPrank();

        // Simulate passing lock period
        vm.roll(block.number + 2);

        // Complete withdrawal
        bytes32[] memory withdrawalIds = new bytes32[](1);
        withdrawalIds[0] = withdrawalId;

        vm.startPrank(alice);
        vaultManager.completeWithdrawals(withdrawalIds);
        vm.stopPrank();

        // Verify balances
        assertEq(mockUnderlyingToken.balanceOf(alice), 900 ether, "Alice did not receive correct L2 withdrawal amount");
        assertEq(vaultManager.vaultShares(alice, aaveVaultL2), aaveVaultL2.totalShares() - sharesWithdrawAmount, "Shares mismatch after L2 withdrawal");
    }
}
