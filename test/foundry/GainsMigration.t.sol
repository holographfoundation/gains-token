// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";

import "../../src/GAINS.sol";
import "../../src/GainsMigration.sol";
import "../mocks/MockHLG.sol"; // The minimal mock

/**
 * @title GainsMigrationTest
 * @notice Tests GainsMigration + GAINS in a scenario close to production,
 *         using MockHLG to replicate real HolographUtilityToken behavior.
 */
contract GainsMigrationTest is Test {
    event Migrated(address indexed user, uint256 amount);

    // Contracts
    MockHLG internal hlg;
    GAINS internal gains;
    GainsMigration internal migration;
    EndpointV2Mock internal endpoint;

    // Test users
    address internal owner = address(0x12345);
    address internal alice = address(0xAAAAA);
    address internal bob = address(0xBBBBB);

    // Starting amounts
    uint256 internal ALICE_STARTING_HLG = 10_000 ether;
    uint256 internal BOB_STARTING_HLG = 5_000 ether;

    // ------------------------------------
    // Setup
    // ------------------------------------
    function setUp() public {
        vm.label(owner, "Owner");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        // 1) Deploy minimal MockHLG to replicate real HolographUtilityToken logic
        hlg = new MockHLG("Holograph Utility Token", "HLG");
        vm.label(address(hlg), "MockHLG");

        // 2) Deploy mock endpoint for GAINS
        endpoint = new EndpointV2Mock(1, address(this));
        vm.label(address(endpoint), "EndpointV2Mock");

        // 3) Deploy GAINS (OFT)
        vm.prank(owner);
        gains = new GAINS("GAINS", "GAINS", address(endpoint), owner);
        vm.label(address(gains), "GAINS");

        // 4) Deploy GainsMigration referencing hlg + GAINS
        migration = new GainsMigration(address(hlg), address(gains));
        vm.label(address(migration), "GainsMigration");

        // 5) As GAINS owner, allow GainsMigration to mint GAINS
        vm.prank(owner);
        gains.setMigrationContract(address(migration));

        // 6) For local testing, mint some HLG to alice + bob
        hlg.mint(alice, ALICE_STARTING_HLG);
        hlg.mint(bob, BOB_STARTING_HLG);
    }

    // ------------------------------------
    // TESTS
    // ------------------------------------

    /**
     * @notice Basic migration scenario: user approves GainsMigration, calls migrate, HLG is burned, GAINS is minted.
     */
    function test_migrate_HappyPath() public {
        // Check initial
        assertEq(hlg.balanceOf(alice), ALICE_STARTING_HLG);
        assertEq(gains.balanceOf(alice), 0);

        // Approve
        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);

        // Migrate
        migration.migrate(amount);
        vm.stopPrank();

        // Post-check
        assertEq(hlg.balanceOf(alice), ALICE_STARTING_HLG - amount);
        assertEq(gains.balanceOf(alice), amount);
    }

    /**
     * @notice If user doesn’t approve GainsMigration, the burn fails with “ERC20: amount exceeds allowance.”
     */
    function test_migrate_Revert_NoApproval() public {
        vm.startPrank(alice);
        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(1_000 ether);
        vm.stopPrank();
    }

    /**
     * @notice If user tries migrating more than they hold, the burn fails with “ERC20: amount exceeds balance.”
     */
    function test_migrate_Revert_InsufficientBalance() public {
        uint256 tooMuch = ALICE_STARTING_HLG + 1 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), tooMuch);

        // Real contract reverts with “ERC20: amount exceeds balance”
        vm.expectRevert("ERC20: amount exceeds balance");
        migration.migrate(tooMuch);
        vm.stopPrank();
    }

    /**
     * @notice GainsMigration is the only contract allowed to call GAINS.mintForMigration
     */
    function test_mintForMigration_RevertIfNotMigrationContract() public {
        vm.startPrank(alice);
        vm.expectRevert("GAINS: not migration contract");
        gains.mintForMigration(alice, 1_000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Only GAINS owner can set the GainsMigration contract
     */
    function test_setMigrationContract_RevertIfNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        gains.setMigrationContract(address(0xDEAD));
        vm.stopPrank();
    }

    /**
     * @notice Confirm GainsMigration emits the Migrated event with correct args
     */
    function test_migrate_EventEmission() public {
        // Approve first
        vm.startPrank(alice);
        hlg.approve(address(migration), 500 ether);

        // Expect event
        vm.expectEmit(true, true, false, true);
        emit Migrated(alice, 500 ether);

        migration.migrate(500 ether);
        vm.stopPrank();
    }
}
