// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";

import "../../src/GainsMigration.sol";
import "../../src/GAINS.sol";
import "../mocks/MockHLG.sol"; // Minimal mock implementing HolographERC20Interface

/**
 * @title GainsMigrationTest
 * @notice Full test suite covering local chain migration from HLG to GAINS.
 */
contract GainsMigrationTest is Test {
    event Migrated(address indexed user, uint256 amount);

    // ============ Contracts and addresses ============
    MockHLG internal hlg;
    GAINS internal gains;
    GainsMigration internal migration;
    EndpointV2Mock internal endpoint;

    // Test users
    address internal owner = address(0x12345);
    address internal alice = address(0xAAAAA);
    address internal bob = address(0xBBBBB);

    // Sample amounts
    uint256 internal ALICE_STARTING_HLG = 10_000 ether;
    uint256 internal BOB_STARTING_HLG = 5_000 ether;

    // ============ Setup ============
    function setUp() public {
        // Label addresses in Foundry traces
        vm.label(owner, "Owner");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        // Deploy a minimal mock of HLG (implements HolographERC20Interface)
        hlg = new MockHLG("Holograph Utility Token", "HLG");
        vm.label(address(hlg), "HLG");

        // Deploy mock endpoint
        endpoint = new EndpointV2Mock(1, address(this));
        vm.label(address(endpoint), "LZEndpoint");

        // Deploy GAINS, setting the owner to `owner`
        vm.prank(owner);
        gains = new GAINS("GAINS", "GAINS", address(endpoint), owner);
        vm.label(address(gains), "GAINS");

        // Deploy GainsMigration referencing HLG and GAINS
        migration = new GainsMigration(address(hlg), address(gains));
        vm.label(address(migration), "GainsMigration");

        // As the GAINS owner, set the migration contract
        vm.prank(owner);
        gains.setMigrationContract(address(migration));

        // For testing, we give Alice and Bob some HLG
        // We'll just "mint" them HLG in the mock
        hlg.mint(alice, ALICE_STARTING_HLG);
        hlg.mint(bob, BOB_STARTING_HLG);
    }

    // ============ Tests: GainsMigration ============

    /**
     * @notice Test the overall happy path: user approves GainsMigration, migrates HLG -> GAINS.
     */
    function test_migrate_HappyPath() public {
        // Pre-check initial balances
        assertEq(hlg.balanceOf(alice), ALICE_STARTING_HLG);
        assertEq(gains.balanceOf(alice), 0);

        // Setup: Alice approves GainsMigration
        uint256 amount = 1_000 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);

        // Migrate
        migration.migrate(amount);
        vm.stopPrank();

        // GainsMigration calls:
        //  1. hlg.sourceBurn(alice, amount)
        //  2. gains.mintForMigration(alice, amount)

        // Post-check: HLG burned from Alice
        assertEq(hlg.balanceOf(alice), ALICE_STARTING_HLG - amount);
        // Post-check: GAINS minted to Alice
        assertEq(gains.balanceOf(alice), amount);
    }

    /**
     * @notice Test migration fails if user didn't approve the GainsMigration contract on HLG.
     */
    function test_migrate_Revert_NoApproval() public {
        // Try migrating without approving
        vm.startPrank(alice);
        vm.expectRevert("ERC20: insufficient allowance");
        migration.migrate(1_000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Test that GainsMigration cannot mint more GAINS than user has HLG (i.e. if user’s HLG was insufficient).
     */
    function test_migrate_Revert_InsufficientHLGBalance() public {
        // If user tries to migrate more than they hold
        uint256 migrateAmount = ALICE_STARTING_HLG + 1 ether;

        vm.startPrank(alice);
        // Approve GainsMigration for the big amount
        hlg.approve(address(migration), migrateAmount);
        // Expect revert from the mock: "HLG: insufficient balance"
        vm.expectRevert("HLG: insufficient balance");
        migration.migrate(migrateAmount);
        vm.stopPrank();

        // Confirm Alice still has the same amount of HLG
        assertEq(hlg.balanceOf(alice), ALICE_STARTING_HLG);
    }

    /**
     * @notice Test that GainsMigration only mints GAINS if the `mintForMigration` call is from GainsMigration.
     *         This covers the scenario where a random user tries to call `mintForMigration` directly on GAINS.
     */
    function test_mintForMigration_RevertIfNotMigrationContract() public {
        // Attempt direct call to GAINS.mintForMigration by a random user
        vm.startPrank(alice);
        vm.expectRevert("GAINS: not migration contract");
        gains.mintForMigration(alice, 1_000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Test that only the GAINS owner can set the migration contract.
     */
    function test_setMigrationContract_RevertIfNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        gains.setMigrationContract(address(0xDEAD));
        vm.stopPrank();
    }

    /**
     * @notice Test that the GainsMigration emits the Migrated event with correct data.
     */
    function test_migrate_EventEmission() public {
        // Approve GainsMigration
        vm.startPrank(alice);
        hlg.approve(address(migration), 500 ether);

        // Expect event
        vm.expectEmit(true, true, false, true);
        emit Migrated(alice, 500 ether);

        migration.migrate(500 ether);
        vm.stopPrank();
    }
}
