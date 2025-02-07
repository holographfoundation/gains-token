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
 *
 * Note: With the new one-way allowlist toggle, the contract is deployed with allowlistActive true by default.
 * For tests that simulate public migration (open to all), we explicitly disable the allowlist by calling
 * migration.setAllowlistActive(false) once at the start of the test.
 * For tests that exercise allowlist functionality, we leave it active.
 */
contract MigrateHLGToGAINSTest is Test {
    error OwnableUnauthorizedAccount(address);

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
        //    (deploy as owner so Ownable is set correctly)
        vm.prank(owner);
        migration = new MigrateHLGToGAINS(address(hlg), address(gains));
        vm.label(address(migration), "MigrateHLGToGAINS");

        // 5) Mint MockHLG tokens to Alice and Bob for testing
        hlg.mint(alice, ALICE_STARTING_HLG);
        hlg.mint(bob, BOB_STARTING_HLG);

        // By default, the allowlist is active (as set in the constructor).
        // For tests that simulate public migration, the allowlist will be disabled explicitly.
    }

    /// @dev Helper to set up migration contract for tests that need it
    function setUpMigrationContract() internal {
        vm.prank(owner);
        gains.setMigrationContract(address(migration));
    }

    // ------------------------------------
    // Migration Tests (Public Migration)
    // ------------------------------------
    /**
     * @notice Test that migrating zero tokens fails.
     */
    function test_migrate_ZeroAmount() public {
        setUpMigrationContract();
        // Disable allowlist to simulate public migration.
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        hlg.approve(address(migration), 0);
        vm.expectRevert(MigrateHLGToGAINS.ZeroAmount.selector);
        migration.migrate(0);
        vm.stopPrank();
    }

    /**
     * @notice Test migrating 1 token works correctly.
     */
    function test_migrate_OneToken() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 1;
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        uint256 preHLGBalance = hlg.balanceOf(alice);
        uint256 preGAINSBalance = gains.balanceOf(alice);
        migration.migrate(amount);
        assertEq(hlg.balanceOf(alice), preHLGBalance - amount);
        assertEq(gains.balanceOf(alice), preGAINSBalance + amount);
        vm.stopPrank();
    }

    /**
     * @notice Test multiple migration calls from the same address.
     */
    function test_migrate_MultipleCalls() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;
        uint256 preHLGBalance = hlg.balanceOf(alice);
        uint256 preGAINSBalance = gains.balanceOf(alice);
        uint256 totalMigrated = 0;
        vm.startPrank(alice);
        for (uint256 i = 0; i < amounts.length; i++) {
            hlg.approve(address(migration), amounts[i]);
            migration.migrate(amounts[i]);
            totalMigrated += amounts[i];
            assertEq(hlg.balanceOf(alice), preHLGBalance - totalMigrated);
            assertEq(gains.balanceOf(alice), preGAINSBalance + totalMigrated);
        }
        vm.stopPrank();
    }

    /**
     * @notice Test migrations from multiple different addresses.
     */
    function test_migrate_MultipleMigrators() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 1000 ether;

        // Test Alice migration
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        uint256 preAliceHLG = hlg.balanceOf(alice);
        uint256 preAliceGAINS = gains.balanceOf(alice);
        migration.migrate(amount);
        assertEq(hlg.balanceOf(alice), preAliceHLG - amount);
        assertEq(gains.balanceOf(alice), preAliceGAINS + amount);
        vm.stopPrank();

        // Test Bob migration
        vm.startPrank(bob);
        hlg.approve(address(migration), amount);
        uint256 preBobHLG = hlg.balanceOf(bob);
        uint256 preBobGAINS = gains.balanceOf(bob);
        migration.migrate(amount);
        assertEq(hlg.balanceOf(bob), preBobHLG - amount);
        assertEq(gains.balanceOf(bob), preBobGAINS + amount);
        vm.stopPrank();
    }

    /**
     * @notice Test contract state changes during migration.
     */
    function test_migrate_StateChecks() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 1000 ether;
        uint256 preTotalHLG = hlg.totalSupply();
        uint256 preTotalGAINS = gains.totalSupply();
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        migration.migrate(amount);
        vm.stopPrank();
        assertEq(hlg.totalSupply(), preTotalHLG - amount, "HLG total supply should decrease");
        assertEq(gains.totalSupply(), preTotalGAINS + amount, "GAINS total supply should increase");
    }

    /**
     * @notice Test migrating full balance.
     */
    function test_migrate_FullBalance() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 fullBalance = hlg.balanceOf(alice);
        vm.startPrank(alice);
        hlg.approve(address(migration), fullBalance);
        migration.migrate(fullBalance);
        assertEq(hlg.balanceOf(alice), 0, "HLG balance should be zero");
        assertEq(gains.balanceOf(alice), fullBalance, "GAINS balance should equal initial HLG balance");
        vm.stopPrank();
    }

    /**
     * @notice Test approval state after migration.
     */
    function test_migrate_ApprovalState() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 1000 ether;
        uint256 approval = 2000 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), approval);
        migration.migrate(amount);
        assertEq(hlg.allowance(alice, address(migration)), approval - amount, "Remaining allowance should be correct");
        vm.stopPrank();
    }

    /**
     * @notice Test migration fails with insufficient approval.
     */
    function test_migrate_RevertWithPartialApproval() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 1000 ether;
        uint256 partialApproval = amount - 1;
        vm.startPrank(alice);
        hlg.approve(address(migration), partialApproval);
        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test event emission during migration.
     */
    function test_migrate_EventSequence() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        vm.expectEmit(true, true, false, true);
        emit MigrateHLGToGAINS.MigratedHLGToGAINS(alice, amount);
        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test gas consumption consistency across migrations.
     */
    function test_migrate_GasConsistency() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 1000 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), amount * 3);
        // First migration (warm up storage)
        migration.migrate(amount);
        uint256 gasBefore = gasleft();
        migration.migrate(amount);
        uint256 gasUsed1 = gasBefore - gasleft();
        gasBefore = gasleft();
        migration.migrate(amount);
        uint256 gasUsed2 = gasBefore - gasleft();
        // Gas usage should be consistent for warm storage calls
        assertApproxEqRel(gasUsed1, gasUsed2, 0.1e18); // 10% tolerance
        vm.stopPrank();
    }

    /**
     * @notice Basic migration scenario: user approves MigrateHLGToGAINS, calls migrate, HLG is burned, GAINS is minted.
     */
    function test_migrate_HappyPath() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        // Check initial balances
        assertEq(hlg.balanceOf(alice), ALICE_STARTING_HLG);
        assertEq(gains.balanceOf(alice), 0);
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
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Migration fails if the user tries to migrate more HLG than they hold.
     */
    function test_migrate_Revert_InsufficientBalance() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 excessiveAmount = ALICE_STARTING_HLG + 1 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), excessiveAmount);
        vm.expectRevert("ERC20: amount exceeds balance");
        migration.migrate(excessiveAmount);
        vm.stopPrank();
    }

    /**
     * @notice Only MigrateHLGToGAINS can call GAINS.mintForMigration.
     *         We revert with a custom error now: NotMigrationContract().
     */
    function test_mintForMigration_RevertIfNotMigrationContract() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        vm.expectRevert(GAINS.NotMigrationContract.selector);
        gains.mintForMigration(alice, 1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Only the GAINS owner can set the MigrateHLGToGAINS contract.
     */
    function test_setMigrationContract_RevertIfNotOwner() public {
        setUpMigrationContract();
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        gains.setMigrationContract(address(0xDEAD));
        vm.stopPrank();
    }

    /**
     * @notice Migration emits a MigratedHLGToGAINS event with the correct parameters.
     */
    function test_migrate_EventEmission() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 500 ether;
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        vm.expectEmit(true, true, false, true);
        emit MigrateHLGToGAINS.MigratedHLGToGAINS(alice, amount);
        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test that setting migration contract to zero address reverts
     *         This must run before the migration contract is set in setUp()
     */
    function test_setMigrationContract_RevertIfZeroAddress() public {
        assertTrue(gains.migrationContract() == address(0), "Migration contract should not be set yet");
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        gains.setMigrationContract(address(0));
        vm.stopPrank();
    }

    /**
     * @notice Test that MigrationContractSet event fires when setting the migration contract for the first time
     *         This must run before the migration contract is set in setUp()
     */
    function test_setMigrationContract_EmitsEvent() public {
        assertTrue(gains.migrationContract() == address(0), "Migration contract should not be set yet");
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit GAINS.MigrationContractSet(address(migration));
        gains.setMigrationContract(address(migration));
        vm.stopPrank();
    }

    /**
     * @notice Test that setting migration contract a second time fails.
     *         We set up the migration contract at the start of the test,
     *         then verify it cannot be set again.
     */
    function test_setMigrationContract_RevertIfAlreadySet() public {
        // First set up the migration contract
        setUpMigrationContract();
        assertTrue(gains.migrationContract() == address(migration), "Migration contract should be set");
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("MigrationContractAlreadySet()"));
        gains.setMigrationContract(address(0xDEAD));
        vm.stopPrank();
    }

    /**
     * @notice Test that migration reverts with BurnFromFailed when burnFrom returns false.
     */
    function test_migrate_Revert_BurnFromFailed() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);
        uint256 amount = 1000 ether;
        // Add Alice to allowlist (for tests that require it, though allowlist is off here)
        vm.prank(owner);
        migration.addToAllowlist(alice);
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        hlg.setShouldBurnSucceed(false);
        vm.expectRevert(MigrateHLGToGAINS.BurnFromFailed.selector);
        migration.migrate(amount);
        vm.stopPrank();
        hlg.setShouldBurnSucceed(true);
    }

    // ------------------------------------
    // Pause Functionality Tests
    // ------------------------------------
    /**
     * @notice Test that when the contract is paused, migration is prevented.
     */
    function test_pause_PreventsMigration() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.pause();
        vm.startPrank(alice);
        hlg.approve(address(migration), 1000 ether);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Test that unpausing the contract allows migration.
     */
    function test_unpause_AllowsMigration() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.prank(owner);
        migration.pause();
        vm.startPrank(alice);
        hlg.approve(address(migration), 1000 ether);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        migration.migrate(1000 ether);
        vm.stopPrank();
        vm.prank(owner);
        migration.unpause();
        vm.startPrank(alice);
        migration.migrate(1000 ether);
        vm.stopPrank();
        assertEq(gains.balanceOf(alice), 1000 ether);
    }

    /**
     * @notice Test that only the owner can pause and unpause the contract.
     */
    function test_pause_AccessControl() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, alice));
        migration.pause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, alice));
        migration.unpause();
    }

    // ------------------------------------
    // Allowlist Functionality Tests (allowlistActive remains true)
    // ------------------------------------
    /**
     * @notice Test that migration reverts if the user is not on the allowlist.
     */
    function test_allowlist_RevertForNonAllowlisted() public {
        setUpMigrationContract();
        uint256 amount = 500 ether;
        // Do not disable allowlist here so that it remains active.
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        vm.expectRevert(MigrateHLGToGAINS.NotOnAllowlist.selector);
        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test that migration allows for allowlisted users.
     */
    function test_allowlist_AllowsMigrationForAllowlisted() public {
        setUpMigrationContract();
        uint256 amount = 500 ether;
        // Add Alice to the allowlist.
        vm.prank(owner);
        migration.addToAllowlist(alice);
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        migration.migrate(amount);
        vm.stopPrank();
        assertEq(gains.balanceOf(alice), amount);
    }

    /**
     * @notice Test that batch adding to allowlist works.
     */
    function test_allowlist_BatchAdd() public {
        setUpMigrationContract();
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;
        vm.prank(owner);
        migration.batchAddToAllowlist(accounts);
        assertTrue(migration.allowlist(alice), "Alice should be in the allowlist");
        assertTrue(migration.allowlist(bob), "Bob should be in the allowlist");
    }

    /**
     * @notice Test that removing from allowlist works.
     */
    function test_allowlist_Remove() public {
        setUpMigrationContract();
        vm.prank(owner);
        migration.addToAllowlist(alice);
        assertTrue(migration.allowlist(alice), "Alice should be in the allowlist");
        vm.prank(owner);
        migration.removeFromAllowlist(alice);
        assertTrue(!migration.allowlist(alice), "Alice should not be in the allowlist");
    }

    /**
     * @notice Test that allowinglist status change emits an event.
     */
    function test_allowlist_AllowlistStatusChangeEmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit MigrateHLGToGAINS.AllowlistStatusChanged(true);
        migration.setAllowlistActive(true); // No state change, as it's already true.
    }

    /**
     * @notice Test that inactive allowlist allows migration.
     */
    function test_allowlist_InactiveAllowsMigration() public {
        setUpMigrationContract();
        uint256 amount = 500 ether;
        vm.prank(owner);
        migration.setAllowlistActive(false);
        vm.startPrank(alice);
        hlg.approve(address(migration), amount);
        migration.migrate(amount);
        vm.stopPrank();
        assertEq(gains.balanceOf(alice), amount);
    }

    /**
     * @notice Test that adding a zero address reverts.
     */
    function test_allowlist_RevertOnZeroAddressAddition() public {
        vm.prank(owner);
        vm.expectRevert(MigrateHLGToGAINS.ZeroAddressProvided.selector);
        migration.addToAllowlist(address(0));
    }

    /**
     * @notice Test that batch adding a zero address reverts.
     */
    function test_allowlist_RevertOnZeroAddressBatchAddition() public {
        setUpMigrationContract();
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = address(0);
        vm.prank(owner);
        vm.expectRevert(MigrateHLGToGAINS.ZeroAddressProvided.selector);
        migration.batchAddToAllowlist(accounts);
    }
}
