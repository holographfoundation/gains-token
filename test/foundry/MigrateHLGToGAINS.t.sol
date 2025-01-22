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
    // GAINS uses custom errors, so we need to define them here
    error NotMigrationContract();

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

        // 5) Mint MockHLG tokens to Alice and Bob for testing
        hlg.mint(alice, ALICE_STARTING_HLG);
        hlg.mint(bob, BOB_STARTING_HLG);
    }

    /// @dev Helper to set up migration contract for tests that need it
    function setUpMigrationContract() internal {
        vm.prank(owner);
        gains.setMigrationContract(address(migration));
    }

    // ------------------------------------
    // TESTS
    // ------------------------------------

    /**
     * @notice Test that migrating zero tokens fails.
     */
    function test_migrate_ZeroAmount() public {
        setUpMigrationContract();
        vm.startPrank(alice);
        hlg.approve(address(migration), 0);
        uint256 preHLGBalance = hlg.balanceOf(alice);
        uint256 preGAINSBalance = gains.balanceOf(alice);
        
        migration.migrate(0);
        
        // Balances should remain unchanged
        assertEq(hlg.balanceOf(alice), preHLGBalance);
        assertEq(gains.balanceOf(alice), preGAINSBalance);
        vm.stopPrank();
    }

    /**
     * @notice Test migrating 1 token works correctly.
     */
    function test_migrate_OneToken() public {
        setUpMigrationContract();
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
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;
        
        uint256 preHLGBalance = hlg.balanceOf(alice);
        uint256 preGAINSBalance = gains.balanceOf(alice);
        uint256 totalMigrated = 0;
        
        vm.startPrank(alice);
        for(uint256 i = 0; i < amounts.length; i++) {
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
        uint256 amount = 1000 ether;

        vm.startPrank(alice);
        hlg.approve(address(migration), amount);

        vm.expectEmit(true, true, false, true);
        emit MigratedHLGToGAINS(alice, amount);

        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test gas consumption consistency across migrations.
     */
    function test_migrate_GasConsistency() public {
        setUpMigrationContract();
        uint256 amount = 1000 ether;
        
        vm.startPrank(alice);
        hlg.approve(address(migration), amount * 3);
        
        // First migration (warm up storage)
        migration.migrate(amount);
        
        // Second migration (measure gas)
        uint256 gasBefore = gasleft();
        migration.migrate(amount);
        uint256 gasUsed1 = gasBefore - gasleft();
        
        // Third migration (measure gas)
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
        // Set up migration contract for this test
        setUpMigrationContract();
        vm.startPrank(alice);
        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Migration fails if the user tries to migrate more HLG than they hold.
     */
    function test_migrate_Revert_InsufficientBalance() public {
        // Set up migration contract for this test
        setUpMigrationContract();
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
        // Set up migration contract for this test
        setUpMigrationContract();
        vm.startPrank(alice);
        // New custom error signature from GAINS
        vm.expectRevert(abi.encodeWithSignature("NotMigrationContract()"));
        gains.mintForMigration(alice, 1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Only the GAINS owner can set the MigrateHLGToGAINS contract.
     */
    function test_setMigrationContract_RevertIfNotOwner() public {
        // Set up migration contract for this test
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
        // Set up migration contract for this test
        setUpMigrationContract();
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
     * @notice Test that MigrationContractUpdated event fires when setting the migration contract for the first time
     *         This must run before the migration contract is set in setUp()
     */
    function test_setMigrationContract_EmitsEvent() public {
        assertTrue(gains.migrationContract() == address(0), "Migration contract should not be set yet");

        vm.startPrank(owner);

        // Expect event from GAINS showing change from zero address to new contract
        vm.expectEmit(true, true, false, true);
        emit GAINS.MigrationContractUpdated(address(0), address(migration));

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

        // Verify migration contract is set correctly
        assertTrue(gains.migrationContract() == address(migration), "Migration contract should be set");

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("MigrationContractAlreadySet()"));
        gains.setMigrationContract(address(0xDEAD));
        vm.stopPrank();
    }
}
