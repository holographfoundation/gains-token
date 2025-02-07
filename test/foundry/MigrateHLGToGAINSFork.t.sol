// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../src/GAINS.sol";
import "../../src/MigrateHLGToGAINS.sol";
import "../mocks/MockHLG.sol";

/**
 * @title MigrateHLGToGAINSFork
 * @notice Fork-based test suite for HLG -> GAINS migration on Sepolia,
 *         mirroring the structure and naming of the non-forked suite.
 */
contract MigrateHLGToGAINSFork is TestHelperOz5 {
    error OwnableUnauthorizedAccount(address);

    // ------------------------------------------------
    // Addresses and contracts
    // ------------------------------------------------

    // Sepolia HLG contract
    address internal constant SEP_HLG = 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1;

    // Matching the variable naming from the non-forked version
    address internal owner = address(0x12345);
    address internal alice = 0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d; // Deployer on Sepolia in your environment
    address internal bob = 0x000000000000000000000000000000000000dEaD; // Another address used for testing

    GAINS internal gains;
    MigrateHLGToGAINS internal migration;

    // ------------------------------------------------
    // Setup
    // ------------------------------------------------

    /**
     * @notice Fork Sepolia, deploy new GAINS & MigrateHLGToGAINS referencing real HLG,
     *         then label addresses for clarity.
     */
    function setUp() public override {
        super.setUp();

        // Fork Sepolia
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));

        // Label addresses
        vm.label(owner, "Owner");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(SEP_HLG, "SepoliaHLG");

        // Set up a mock endpoint for GAINS if needed (LayerZero).
        // Using index '1' to match a minimal local environment.
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy GAINS with "owner" as the contract owner
        vm.prank(owner);
        gains = new GAINS("GAINS", "GAINS", address(endpoints[1]), owner);
        vm.label(address(gains), "GAINS");

        // Deploy MigrateHLGToGAINS referencing SEP_HLG + GAINS
        vm.prank(owner);
        migration = new MigrateHLGToGAINS(SEP_HLG, address(gains));
        vm.label(address(migration), "MigrateHLGToGAINS");

        // Set MigrateHLGToGAINS as the migration contract in GAINS
        vm.prank(owner);
        gains.setMigrationContract(address(migration));

        // By default, the allowlist is active (as set in the constructor).
        // For public migration tests, the allowlist will be disabled explicitly in the test.
    }

    // ------------------------------------------------
    // Migration Tests (Public Migration)
    // ------------------------------------------------
    /**
     * @notice Test that migration reverts with ZeroAmount when the amount is zero.
     */
    function test_migrate_ZeroAmount() public {
        // Disable allowlist to simulate public migration.
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        IERC20(SEP_HLG).approve(address(migration), 0);
        vm.expectRevert(MigrateHLGToGAINS.ZeroAmount.selector);
        migration.migrate(0);
        vm.stopPrank();
    }

    /**
     * @notice Test that migration works for one token.
     */
    function test_migrate_OneToken() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 amount = 1 ether;
        IERC20(SEP_HLG).approve(address(migration), amount);
        uint256 preHLG = IERC20(SEP_HLG).balanceOf(alice);
        uint256 preGAINS = gains.balanceOf(alice);
        migration.migrate(amount);
        assertEq(IERC20(SEP_HLG).balanceOf(alice), preHLG - amount);
        assertEq(gains.balanceOf(alice), preGAINS + amount);
        vm.stopPrank();
    }

    /**
     * @notice Test that migration works for multiple calls.
     */
    function test_migrate_MultipleCalls() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;
        uint256 totalToApprove = amounts[0] + amounts[1] + amounts[2];
        IERC20(SEP_HLG).approve(address(migration), totalToApprove);
        uint256 preHLG = IERC20(SEP_HLG).balanceOf(alice);
        uint256 preGAINS = gains.balanceOf(alice);
        uint256 migrated;
        for (uint256 i = 0; i < amounts.length; i++) {
            migration.migrate(amounts[i]);
            migrated += amounts[i];
            assertEq(IERC20(SEP_HLG).balanceOf(alice), preHLG - migrated);
            assertEq(gains.balanceOf(alice), preGAINS + migrated);
        }
        vm.stopPrank();
    }

    /**
     * @notice Test that migration works for multiple migrators.
     */
    function test_migrate_MultipleMigrators() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        uint256 amount = 500 ether;

        // Ensure bob has enough HLG on chain if testing real balances
        // Possibly transfer from alice -> bob if bob has none
        vm.startPrank(alice);
        uint256 aliceBalance = IERC20(SEP_HLG).balanceOf(alice);
        if (aliceBalance < amount * 2) {
            revert("Alice does not have enough HLG to fund Bob in fork. Adjust test or addresses accordingly.");
        }
        IERC20(SEP_HLG).transfer(bob, amount);
        vm.stopPrank();

        // 1) Alice migrates
        vm.startPrank(alice);
        IERC20(SEP_HLG).approve(address(migration), amount);
        uint256 preAliceHLG = IERC20(SEP_HLG).balanceOf(alice);
        uint256 preAliceGAINS = gains.balanceOf(alice);
        migration.migrate(amount);
        assertEq(IERC20(SEP_HLG).balanceOf(alice), preAliceHLG - amount);
        assertEq(gains.balanceOf(alice), preAliceGAINS + amount);
        vm.stopPrank();

        // 2) Bob migrates
        vm.startPrank(bob);
        IERC20(SEP_HLG).approve(address(migration), amount);
        uint256 preBobHLG = IERC20(SEP_HLG).balanceOf(bob);
        uint256 preBobGAINS = gains.balanceOf(bob);
        migration.migrate(amount);
        assertEq(IERC20(SEP_HLG).balanceOf(bob), preBobHLG - amount);
        assertEq(gains.balanceOf(bob), preBobGAINS + amount);
        vm.stopPrank();
    }

    /**
     * @notice Test contract state changes during migration.
     */
    function test_migrate_StateChecks() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 amount = 1000 ether;
        IERC20(SEP_HLG).approve(address(migration), amount);
        uint256 preHLG = IERC20(SEP_HLG).balanceOf(alice);
        uint256 preGAINS = gains.balanceOf(alice);
        migration.migrate(amount);
        vm.stopPrank();
        assertEq(IERC20(SEP_HLG).balanceOf(alice), preHLG - amount, "HLG total supply should decrease");
        assertEq(gains.balanceOf(alice), preGAINS + amount, "GAINS total supply should increase");
    }

    /**
     * @notice Test migrating full balance.
     */
    function test_migrate_FullBalance() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 balance = IERC20(SEP_HLG).balanceOf(alice);
        IERC20(SEP_HLG).approve(address(migration), balance);
        migration.migrate(balance);
        assertEq(IERC20(SEP_HLG).balanceOf(alice), 0, "HLG balance should be zero");
        assertEq(gains.balanceOf(alice), balance, "GAINS balance should equal initial HLG balance");
        vm.stopPrank();
    }

    /**
     * @notice Test approval state after migration.
     */
    function test_migrate_ApprovalState() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 approveAmt = 2000 ether;
        uint256 migrateAmt = 1000 ether;
        IERC20(SEP_HLG).approve(address(migration), approveAmt);
        migration.migrate(migrateAmt);
        uint256 remaining = IERC20(SEP_HLG).allowance(alice, address(migration));
        assertEq(remaining, approveAmt - migrateAmt, "Remaining allowance should be correct");
        vm.stopPrank();
    }

    /**
     * @notice Test migration fails with insufficient approval.
     */
    function test_migrate_RevertWithPartialApproval() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 amount = 1000 ether;
        uint256 partialApprove = 999 ether;
        IERC20(SEP_HLG).approve(address(migration), partialApprove);
        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test that migration emits an event.
     */
    function test_migrate_EventSequence() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 amount = 1000 ether;
        IERC20(SEP_HLG).approve(address(migration), amount);
        vm.expectEmit(true, true, false, true);
        emit MigrateHLGToGAINS.MigratedHLGToGAINS(alice, amount);
        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test that migration has consistent gas usage.
     */
    function test_migrate_GasConsistency() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 amount = 1000 ether;
        IERC20(SEP_HLG).approve(address(migration), amount * 3);
        // Warm-up
        migration.migrate(amount);
        uint256 gasBefore = gasleft();
        migration.migrate(amount);
        uint256 gasUsed1 = gasBefore - gasleft();
        gasBefore = gasleft();
        migration.migrate(amount);
        uint256 gasUsed2 = gasBefore - gasleft();
        assertApproxEqRel(gasUsed1, gasUsed2, 0.1e18); // 10% tolerance
        vm.stopPrank();
    }

    /**
     * @notice Test that migration works for a happy path.
     */
    function test_migrate_HappyPath() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 preHLG = IERC20(SEP_HLG).balanceOf(alice);
        uint256 preGAINS = gains.balanceOf(alice);
        uint256 amount = 1000 ether;
        IERC20(SEP_HLG).approve(address(migration), amount);
        migration.migrate(amount);
        vm.stopPrank();
        assertEq(IERC20(SEP_HLG).balanceOf(alice), preHLG - amount);
        assertEq(gains.balanceOf(alice), preGAINS + amount);
    }

    /**
     * @notice Test that migration reverts if the user has no approval.
     */
    function test_migrate_Revert_NoApproval() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Test that migration reverts if the user tries to migrate more HLG than they hold.
     */
    function test_migrate_Revert_InsufficientBalance() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 userBal = IERC20(SEP_HLG).balanceOf(alice);
        uint256 excessive = userBal + 1 ether;
        IERC20(SEP_HLG).approve(address(migration), excessive);
        vm.expectRevert("ERC20: amount exceeds balance");
        migration.migrate(excessive);
        vm.stopPrank();
    }

    /**
     * @notice Test that minting for migration reverts if not migration contract.
     */
    function test_mintForMigration_RevertIfNotMigrationContract() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        vm.expectRevert(GAINS.NotMigrationContract.selector);
        gains.mintForMigration(alice, 1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Test that setting migration contract reverts if not owner.
     */
    function test_setMigrationContract_RevertIfNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, alice));
        gains.setMigrationContract(address(0xDEAD));
        vm.stopPrank();
    }

    /**
     * @notice Test that migration emits an event.
     */
    function test_migrate_EventEmission() public {
        vm.prank(owner);
        migration.setAllowlistActive(false);

        vm.startPrank(alice);
        uint256 amount = 500 ether;
        IERC20(SEP_HLG).approve(address(migration), amount);
        vm.expectEmit(true, true, false, true);
        emit MigrateHLGToGAINS.MigratedHLGToGAINS(alice, amount);
        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test that setting migration contract to zero address reverts.
     *         This must run before the migration contract is set in setUp().
     */
    function test_setMigrationContract_RevertIfZeroAddress() public {
        // Must happen before setMigrationContract is called,
        // but we already set it in setUp(). So we do a fresh GAINS for demonstration.
        GAINS freshGains = new GAINS("GAINS", "GAINS", address(endpoints[1]), owner);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        freshGains.setMigrationContract(address(0));
    }

    /**
     * @notice Test that setting migration contract emits an event.
     */
    function test_setMigrationContract_EmitsEvent() public {
        // Again, use a fresh GAINS so the migration contract is not yet set
        GAINS freshGains = new GAINS("GAINS", "GAINS", address(endpoints[1]), owner);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit GAINS.MigrationContractSet(address(migration));
        freshGains.setMigrationContract(address(migration));
    }

    /**
     * @notice Test that setting migration contract a second time fails.
     */
    function test_setMigrationContract_RevertIfAlreadySet() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("MigrationContractAlreadySet()"));
        gains.setMigrationContract(address(0xDEAD));
    }

    /**
     * @notice Test that migration reverts with BurnFromFailed when burnFrom returns false.
     */
    function test_migrate_Revert_BurnFromFailed() public {
        // Use a local MockHLG to force burn failure
        MockHLG localHLG = new MockHLG("Mock HLG", "HLG");
        localHLG.mint(alice, 1000 ether);

        vm.startPrank(owner);
        GAINS freshGains = new GAINS("GAINS", "GAINS", address(endpoints[1]), owner);
        MigrateHLGToGAINS localMigration = new MigrateHLGToGAINS(address(localHLG), address(freshGains));
        freshGains.setMigrationContract(address(localMigration));

        // Add Alice to the allowlist
        localMigration.addToAllowlist(alice);
        vm.stopPrank();

        vm.startPrank(alice);
        // **Fix: Approve sufficient allowance before setting burn failure**
        localHLG.approve(address(localMigration), 1000 ether);

        // **Set burn failure AFTER approval**
        localHLG.setShouldBurnSucceed(false);

        vm.expectRevert(MigrateHLGToGAINS.BurnFromFailed.selector);
        localMigration.migrate(1000 ether);
        vm.stopPrank();

        // Reset flag for other tests
        localHLG.setShouldBurnSucceed(true);
    }

    // ------------------------------------------------
    // Pause Functionality Tests
    // ------------------------------------------------
    /**
     * @notice Test that when the contract is paused, migration is prevented.
     */
    function test_pause_PreventsMigration() public {
        vm.prank(owner);
        migration.pause();
        vm.startPrank(alice);
        IERC20(SEP_HLG).approve(address(migration), 1000 ether);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Test that unpausing the contract allows migration.
     */
    function test_unpause_AllowsMigration() public {
        vm.startPrank(owner);
        migration.pause();
        migration.setAllowlistActive(false);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(SEP_HLG).approve(address(migration), 1000 ether);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        migration.migrate(1000 ether);
        vm.stopPrank();
        vm.prank(owner);
        migration.unpause();
        vm.startPrank(alice);
        migration.migrate(1000 ether);
        vm.stopPrank();
    }

    /**
     * @notice Test that non-owner cannot pause or unpause the contract.
     */
    function test_pause_AccessControl() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, alice));
        migration.pause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, alice));
        migration.unpause();
    }

    // ------------------------------------------------
    // Allowlist Functionality Tests (allowlistActive remains true)
    // ------------------------------------------------
    /**
     * @notice Test that migration reverts for non-allowlisted users.
     */
    function test_allowlist_RevertForNonAllowlisted() public {
        uint256 amount = 500 ether;
        // Do not disable allowlist so it remains active.
        vm.startPrank(alice);
        IERC20(SEP_HLG).approve(address(migration), amount);
        vm.expectRevert(MigrateHLGToGAINS.NotOnAllowlist.selector);
        migration.migrate(amount);
        vm.stopPrank();
    }

    /**
     * @notice Test that migration is allowed for allowlisted users.
     */
    function test_allowlist_AllowsMigrationForAllowlisted() public {
        uint256 amount = 500 ether;
        vm.prank(owner);
        migration.setAllowlistActive(true);
        vm.prank(owner);
        migration.addToAllowlist(alice);
        vm.startPrank(alice);
        IERC20(SEP_HLG).approve(address(migration), amount);
        migration.migrate(amount);
        vm.stopPrank();
        assertEq(gains.balanceOf(alice), amount);
    }

    /**
     * @notice Test that batch adding to the allowlist works.
     */
    function test_allowlist_BatchAdd() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;
        vm.prank(owner);
        migration.batchAddToAllowlist(accounts);
        assertTrue(migration.allowlist(alice), "Alice should be in the allowlist");
        assertTrue(migration.allowlist(bob), "Bob should be in the allowlist");
    }

    /**
     * @notice Test that removing from the allowlist works.
     */
    function test_allowlist_Remove() public {
        vm.prank(owner);
        migration.addToAllowlist(alice);
        assertTrue(migration.allowlist(alice), "Alice should be in the allowlist");
        vm.prank(owner);
        migration.removeFromAllowlist(alice);
        assertFalse(migration.allowlist(alice), "Alice should not be in the allowlist");
    }

    /**
     * @notice Test that the allowlist status change emits an event.
     */
    function test_allowlist_AllowlistStatusChangeEmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit MigrateHLGToGAINS.AllowlistStatusChanged(true);
        migration.setAllowlistActive(true); // No state change, as it's already true.
    }

    /**
     * @notice Test that when the allowlist is inactive, migration is allowed for all users.
     */
    function test_allowlist_InactiveAllowsMigration() public {
        uint256 amount = 500 ether;
        vm.prank(owner);
        migration.setAllowlistActive(false);
        vm.startPrank(alice);
        IERC20(SEP_HLG).approve(address(migration), amount);
        migration.migrate(amount);
        vm.stopPrank();
        assertEq(gains.balanceOf(alice), amount);
    }

    /**
     * @notice Test that adding a zero address to the allowlist reverts.
     */
    function test_allowlist_RevertOnZeroAddressAddition() public {
        vm.prank(owner);
        vm.expectRevert(MigrateHLGToGAINS.ZeroAddressProvided.selector);
        migration.addToAllowlist(address(0));
    }

    /**
     * @notice Test that adding a zero address to the allowlist reverts.
     */
    function test_allowlist_RevertOnZeroAddressBatchAddition() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = address(0);
        vm.prank(owner);
        vm.expectRevert(MigrateHLGToGAINS.ZeroAddressProvided.selector);
        migration.batchAddToAllowlist(accounts);
    }
}
