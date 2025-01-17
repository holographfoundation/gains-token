// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";

import "../../src/GAINS.sol";
import "../../src/MigrateHLGToGAINS.sol";
import "../mocks/MockHLG.sol"; // The minimal mock for HolographERC20Interface

/**
 * @title MigrateHLGToGAINSTest
 * @notice Tests MigrateHLGToGAINS + GAINS in a scenario close to production,
 *         using MockHLG to replicate real HolographUtilityToken behavior.
 */
contract MigrateHLGToGAINSTest is Test {
    event MigratedHLGToGAINS(address indexed user, uint256 amount);

    // Contracts
    MockHLG internal hlg;
    GAINS internal gains;
    MigrateHLGToGAINS internal migration;
    EndpointV2Mock internal endpoint;

    // Test users
    address internal owner = address(0x12345);
    address internal alice = address(0xAAAAA);
    address internal bob = address(0xBBBBB);

    // Starting amounts
    uint256 internal constant ALICE_STARTING_HLG = 10_000 ether;
    uint256 internal constant BOB_STARTING_HLG = 5_000 ether;

    // ------------------------------------
    // Setup
    // ------------------------------------
    function setUp() public {
        // Label addresses for better traceability
        vm.label(owner, "Owner");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        // 1) Deploy minimal MockHLG to replicate HolographUtilityToken behavior
        hlg = new MockHLG("Holograph Utility Token", "HLG");
        vm.label(address(hlg), "MockHLG");

        // 2) Deploy mock endpoint for GAINS
        endpoint = new EndpointV2Mock(1, address(this));
        vm.label(address(endpoint), "EndpointV2Mock");

        // 3) Deploy GAINS (OFT)
        vm.prank(owner);
        gains = new GAINS("GAINS", "GAINS", address(endpoint), owner);
        vm.label(address(gains), "GAINS");

        // 4) Deploy MigrateHLGToGAINS referencing MockHLG + GAINS
        migration = new MigrateHLGToGAINS(address(hlg), address(gains));
        vm.label(address(migration), "MigrateHLGToGAINS");

        // 5) As GAINS owner, allow MigrateHLGToGAINS to mint GAINS
        vm.prank(owner);
        gains.setMigrationContract(address(migration));

        // 6) Mint MockHLG tokens to Alice and Bob for testing
        hlg.mint(alice, ALICE_STARTING_HLG);
        hlg.mint(bob, BOB_STARTING_HLG);
    }

    // ------------------------------------
    // TESTS
    // ------------------------------------

    /**
     * @notice Basic migration scenario: user approves MigrateHLGToGAINS, calls migrate, HLG is burned, GAINS is minted.
     */
    function test_migrate_HappyPath() public {
        // Check initial balances
        assertEq(hlg.balanceOf(alice), ALICE_STARTING_HLG);
        assertEq(gains.balanceOf(alice), 0);

        // Approve MigrateHLGToGAINS
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);

        // Migrate HLG -> GAINS
        migration.migrate(amount);
        vm.stopPrank();

        // Post-migration checks
        assertEq(hlg.balanceOf(alice), ALICE_STARTING_HLG - amount);
        assertEq(gains.balanceOf(alice), amount);
    }

    /**
     * @notice Migration fails if the user doesn’t approve MigrateHLGToGAINS.
     */
    function test_migrate_Revert_NoApproval() public {
        vm.startPrank(alice);
        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Migration fails if the user tries to migrate more HLG than they hold.
     */
    function test_migrate_Revert_InsufficientBalance() public {
        uint256 excessiveAmount = ALICE_STARTING_HLG + 1 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), excessiveAmount);

        vm.expectRevert("ERC20: amount exceeds balance");
        migration.migrate(excessiveAmount);
        vm.stopPrank();
    }

    /**
     * @notice Only MigrateHLGToGAINS can call GAINS.mintForMigration.
     */
    function test_mintForMigration_RevertIfNotMigrationContract() public {
        vm.startPrank(alice);
        vm.expectRevert("GAINS: not migration contract");
        gains.mintForMigration(alice, 1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Only the GAINS owner can set the MigrateHLGToGAINS contract.
     */
    function test_setMigrationContract_RevertIfNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        gains.setMigrationContract(address(0xDEAD));
        vm.stopPrank();
    }

    /**
     * @notice Migration emits a MigratedHLGToGAINS event with the correct parameters.
     */
    function test_migrate_EventEmission() public {
        uint256 amount = 500 ether;

        // Approve MigrateHLGToGAINS
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);

        // Expect the event
        vm.expectEmit(true, true, false, true);
        emit MigratedHLGToGAINS(alice, amount);

        // Trigger migration
        migration.migrate(amount);
        vm.stopPrank();
    }
}
