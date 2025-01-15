// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../src/GAINS.sol";
import "../../src/MigrateHLGToGAINS.sol";

/**
 * @title MigrateHLGToGAINSFork
 * @notice Demonstrates how to fork Sepolia to test HLG -> GAINS migration in a more realistic environment.
 *
 */
contract MigrateHLGToGAINSFork is TestHelperOz5 {
    // The HLG proxy (HolographUtilityToken) address on Sepolia
    address internal constant SEP_HLG = 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1;

    // We'll deploy our own GAINS + MigrateHLGToGAINS on the fork
    GAINS internal gains;
    MigrateHLGToGAINS internal migration;

    // The address of the deployer of HolographUtilityToken on Sepolia
    address internal deployer = 0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d;

    function setUp() public override {
        super.setUp();

        // Fork Sepolia
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));

        // Set up LayerZero endpoints
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy GAINS contract
        gains = new GAINS("GAINS", "GAINS", address(endpoints[1]), address(this));

        // Deploy MigrateHLGToGAINS contract
        migration = new MigrateHLGToGAINS(SEP_HLG, address(gains));

        // Set MigrateHLGToGAINS as the migration contract for GAINS
        gains.setMigrationContract(address(migration));

        // Label addresses for better traceability
        vm.label(SEP_HLG, "SepoliaHLG");
        vm.label(address(gains), "GAINS");
        vm.label(address(migration), "MigrateHLGToGAINS");
        vm.label(deployer, "deployer");
    }

    /**
     * @notice Verifies basic migration scenario with 1 HLG.
     */
    function test_ForkMigrateHLGToGAINS_HappyPath() external {
        uint256 hlgAmount = 1 ether;

        vm.startPrank(deployer);

        // Approve the migration
        IERC20(SEP_HLG).approve(address(migration), hlgAmount);

        // Record pre-migration balances
        uint256 preHLGBalance = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 preGainsBalance = gains.balanceOf(deployer);

        // Perform migration
        migration.migrate(hlgAmount);

        // Record post-migration balances
        uint256 postHLGBalance = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 postGainsBalance = gains.balanceOf(deployer);

        // Assertions
        assertEq(preHLGBalance - hlgAmount, postHLGBalance);
        assertEq(preGainsBalance + hlgAmount, postGainsBalance);

        vm.stopPrank();
    }

    /**
     * @notice Ensures migration fails if user does not approve MigrateHLGToGAINS.
     */
    function test_ForkMigrateHLGToGAINS_Revert_NoApproval() external {
        uint256 hlgAmount = 1 ether;

        vm.startPrank(deployer);

        // Attempt migration without approval
        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(hlgAmount);

        vm.stopPrank();
    }

    /**
     * @notice Ensures migration fails if user attempts to migrate more HLG than they hold.
     */
    function test_ForkMigrateHLGToGAINS_Revert_InsufficientBalance() external {
        uint256 deployerBalance = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 excessiveAmount = deployerBalance + 1 ether;

        vm.startPrank(deployer);

        // Approve migration for more than balance
        IERC20(SEP_HLG).approve(address(migration), excessiveAmount);

        // Attempt migration
        vm.expectRevert("ERC20: amount exceeds balance");
        migration.migrate(excessiveAmount);

        vm.stopPrank();
    }

    /**
     * @notice Confirms that only the migration contract can call `mintForMigration` on GAINS.
     */
    function testForkMintForMigration_RevertIfNotMigrationContract() external {
        uint256 gainsAmount = 1 ether;

        vm.startPrank(deployer);

        // Attempt direct mint
        vm.expectRevert("GAINS: not migration contract");
        gains.mintForMigration(deployer, gainsAmount);

        vm.stopPrank();
    }

    /**
     * @notice Ensures only the GAINS owner can set the migration contract.
     */
    function testForkSetMigrationContract_RevertIfNotOwner() external {
        address newMigrationContract = address(0xDEAD);

        vm.startPrank(deployer);

        // Attempt to set migration contract as a non-owner
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", deployer));
        gains.setMigrationContract(newMigrationContract);

        vm.stopPrank();
    }

    /**
     * @notice Verifies event emission during successful migration.
     */
    function test_ForkMigrateHLGToGAINS_EventEmission() external {
        uint256 hlgAmount = 1 ether;

        vm.startPrank(deployer);

        // Approve migration
        IERC20(SEP_HLG).approve(address(migration), hlgAmount);

        // Expect the event
        vm.expectEmit(true, true, false, true);
        emit MigrateHLGToGAINS.Migrated(deployer, hlgAmount);

        // Perform migration
        migration.migrate(hlgAmount);

        vm.stopPrank();
    }

    /**
     * @notice Ensures that no unexpected state changes occur during migration with exact amounts.
     */
    function test_ForkMigrateHLGToGAINS_StateConsistency() external {
        uint256 hlgAmount = 2 ether;

        vm.startPrank(deployer);

        // Approve migration
        IERC20(SEP_HLG).approve(address(migration), hlgAmount);

        // Pre-migration balances
        uint256 preHLGBalance = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 preGainsBalance = gains.balanceOf(deployer);

        // Perform migration
        migration.migrate(hlgAmount);

        // Post-migration balances
        uint256 postHLGBalance = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 postGainsBalance = gains.balanceOf(deployer);

        // Verify balances
        assertEq(preHLGBalance - hlgAmount, postHLGBalance);
        assertEq(preGainsBalance + hlgAmount, postGainsBalance);

        vm.stopPrank();
    }

    /**
     * @notice Attempts migration with zero HLG, expecting no state change or errors.
     */
    function test_ForkMigrateHLGToGAINS_ZeroAmount() external {
        uint256 hlgAmount = 0;

        vm.startPrank(deployer);

        // Approve migration
        IERC20(SEP_HLG).approve(address(migration), hlgAmount);

        // Perform migration
        migration.migrate(hlgAmount);

        // Post-migration checks
        uint256 deployerGainsBal = gains.balanceOf(deployer);
        uint256 deployerHLGBal = IERC20(SEP_HLG).balanceOf(deployer);

        // Verify balances unchanged
        assertEq(deployerGainsBal, 0);
        assertEq(deployerHLGBal, IERC20(SEP_HLG).balanceOf(deployer));

        vm.stopPrank();
    }
}
