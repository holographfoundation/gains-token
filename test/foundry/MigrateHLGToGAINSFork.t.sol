// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../src/GAINS.sol";
import "../../src/MigrateHLGToGAINS.sol";
import "../mocks/MockHLG.sol";

/**
 * @title MigrateHLGToGAINSFork
 * @notice Demonstrates how to fork Sepolia to test HLG -> GAINS migration in a more realistic environment.
 *
 *         This suite has been expanded to mirror the coverage found in the non-forked version.
 *         It tests multiple migration scenarios, event emissions, setMigrationContract flows,
 *         and gas usage patterns to ensure robust coverage.
 */
contract MigrateHLGToGAINSFork is TestHelperOz5 {
    // GAINS uses custom errors so we need to define them here
    error NotMigrationContract();
    error ZeroAddress();
    error MigrationContractAlreadySet();

    // The HLG proxy (HolographUtilityToken) address on Sepolia
    address internal constant SEP_HLG = 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1;

    // We'll deploy our own GAINS + MigrateHLGToGAINS on the fork
    GAINS internal gains;
    MigrateHLGToGAINS internal migration;

    // The address of the deployer of HolographUtilityToken on Sepolia
    address internal deployer = 0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d;

    // Gets funded with HLG for testing
    address internal secondMigrator = 0x000000000000000000000000000000000000dEaD;

    // For event-checking
    event MigratedHLGToGAINS(address indexed user, uint256 amount);
    event MigrationContractSet(address indexed migrationContract);

    // ------------------------------------
    // Setup
    // ------------------------------------

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
        vm.label(secondMigrator, "secondMigrator");
    }

    // ------------------------------------
    // TESTS
    // ------------------------------------

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
    function test_ForkMintForMigration_RevertIfNotMigrationContract() external {
        uint256 gainsAmount = 1 ether;

        vm.startPrank(deployer);

        // Attempt direct mint
        vm.expectRevert(abi.encodeWithSignature("NotMigrationContract()"));
        gains.mintForMigration(deployer, gainsAmount);

        vm.stopPrank();
    }

    /**
     * @notice Ensures only the GAINS owner can set the migration contract.
     */
    function test_ForkSetMigrationContract_RevertIfNotOwner() external {
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
        emit MigratedHLGToGAINS(deployer, hlgAmount);

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
        vm.expectRevert(MigrateHLGToGAINS.ZeroAmount.selector);
        migration.migrate(0);

        vm.stopPrank();
    }

    /**
     * @notice Tests multiple consecutive migrations from the same address.
     */
    function test_ForkMigrateHLGToGAINS_MultipleCalls() external {
        // We'll do multiple calls from deployer.
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0.5 ether;
        amounts[1] = 1 ether;
        amounts[2] = 2 ether;

        vm.startPrank(deployer);

        // Approve for total
        uint256 total = amounts[0] + amounts[1] + amounts[2];
        IERC20(SEP_HLG).approve(address(migration), total);

        uint256 preHLGBalance = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 preGAINSBalance = gains.balanceOf(deployer);

        // Perform each migration
        uint256 migrated;
        for (uint256 i = 0; i < amounts.length; i++) {
            migration.migrate(amounts[i]);
            migrated += amounts[i];

            assertEq(IERC20(SEP_HLG).balanceOf(deployer), preHLGBalance - migrated);
            assertEq(gains.balanceOf(deployer), preGAINSBalance + migrated);
        }

        vm.stopPrank();
    }

    /**
     * @notice Tests migrating 1 token works correctly.
     */
    function test_ForkMigrateHLGToGAINS_OneToken() external {
        uint256 amount = 1 ether; // 1 token

        vm.startPrank(deployer);

        // Approve migration
        IERC20(SEP_HLG).approve(address(migration), amount);

        // Record pre-migration balances
        uint256 preHLGBalance = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 preGainsBalance = gains.balanceOf(deployer);

        // Perform migration
        migration.migrate(amount);

        // Record post-migration balances
        uint256 postHLGBalance = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 postGainsBalance = gains.balanceOf(deployer);

        // Verify balances
        assertEq(postHLGBalance, preHLGBalance - amount, "HLG balance mismatch after migration");
        assertEq(postGainsBalance, preGainsBalance + amount, "GAINS balance mismatch after migration");

        vm.stopPrank();
    }

    /**
     * @notice Tests migration from multiple different addresses.
     *         Requires that both addresses actually hold HLG on Sepolia.
     */
    function test_ForkMigrateHLGToGAINS_MultipleMigrators() external {
        uint256 amount = 0.5 ether;

        // 1) Fund the secondMigrator if it has zero HLG
        uint256 secondMigratorPreHLG = IERC20(SEP_HLG).balanceOf(secondMigrator);
        if (secondMigratorPreHLG < amount) {
            // Transfer enough HLG from deployer to secondMigrator
            vm.startPrank(deployer);
            IERC20(SEP_HLG).transfer(secondMigrator, amount - secondMigratorPreHLG);
            vm.stopPrank();
        }

        // Ensure secondMigrator has the required amount
        assertEq(IERC20(SEP_HLG).balanceOf(secondMigrator), amount, "Second migrator should have enough HLG");

        // 2) Deployer migrates
        vm.startPrank(deployer);
        IERC20(SEP_HLG).approve(address(migration), amount);
        uint256 preDeployerHLG = IERC20(SEP_HLG).balanceOf(deployer);
        uint256 preDeployerGAINS = gains.balanceOf(deployer);
        migration.migrate(amount);

        assertEq(IERC20(SEP_HLG).balanceOf(deployer), preDeployerHLG - amount, "Deployer HLG balance mismatch");
        assertEq(gains.balanceOf(deployer), preDeployerGAINS + amount, "Deployer GAINS balance mismatch");
        vm.stopPrank();

        // 3) secondMigrator migrates
        vm.startPrank(secondMigrator);
        uint256 preSecondHLG = IERC20(SEP_HLG).balanceOf(secondMigrator);
        uint256 preSecondGAINS = gains.balanceOf(secondMigrator);

        IERC20(SEP_HLG).approve(address(migration), amount);
        migration.migrate(amount);

        assertEq(
            IERC20(SEP_HLG).balanceOf(secondMigrator),
            preSecondHLG - amount,
            "Second migrator HLG balance mismatch"
        );
        assertEq(gains.balanceOf(secondMigrator), preSecondGAINS + amount, "Second migrator GAINS balance mismatch");
        vm.stopPrank();
    }

    /**
     * @notice Tests migrating the full balance of the user.
     *         We check that the user’s HLG goes to zero and they receive the same amount in GAINS.
     */
    function test_ForkMigrateHLGToGAINS_FullBalance() external {
        vm.startPrank(deployer);

        uint256 fullBalance = IERC20(SEP_HLG).balanceOf(deployer);
        IERC20(SEP_HLG).approve(address(migration), fullBalance);

        migration.migrate(fullBalance);

        assertEq(IERC20(SEP_HLG).balanceOf(deployer), 0, "HLG balance should be zero after full migration");
        assertEq(gains.balanceOf(deployer), fullBalance, "GAINS balance should match the full original HLG balance");

        vm.stopPrank();
    }

    /**
     * @notice Tests that after migrating some HLG, the approval/allowance is reduced accordingly.
     */
    function test_ForkMigrateHLGToGAINS_ApprovalState() external {
        vm.startPrank(deployer);

        uint256 amountToApprove = 5 ether;
        uint256 amountToMigrate = 3 ether;

        IERC20(SEP_HLG).approve(address(migration), amountToApprove);

        // Migrate less than the full allowance
        migration.migrate(amountToMigrate);

        uint256 remainingAllowance = IERC20(SEP_HLG).allowance(deployer, address(migration));
        assertEq(remainingAllowance, amountToApprove - amountToMigrate, "Remaining allowance should match expected");

        vm.stopPrank();
    }

    /**
     * @notice Ensures migration fails with partial approval (less than requested).
     */
    function test_ForkMigrateHLGToGAINS_RevertWithPartialApproval() external {
        vm.startPrank(deployer);

        uint256 amountToApprove = 3 ether;
        uint256 amountToMigrate = 4 ether; // More than approved

        IERC20(SEP_HLG).approve(address(migration), amountToApprove);

        vm.expectRevert("ERC20: amount exceeds allowance");
        migration.migrate(amountToMigrate);

        vm.stopPrank();
    }

    /**
     * @notice Tests sequence of events for multiple migrations, measuring gas to ensure consistency.
     */
    function test_ForkMigrateHLGToGAINS_GasConsistency() external {
        vm.startPrank(deployer);

        uint256 amount = 1 ether;
        IERC20(SEP_HLG).approve(address(migration), amount * 3);

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

        // Very rough check: we expect them to be in the same ballpark
        // Example: 20% difference allowed
        uint256 lowerBound = (gasUsed1 * 80) / 100; // -20%
        uint256 upperBound = (gasUsed1 * 120) / 100; // +20%
        assertTrue(gasUsed2 >= lowerBound && gasUsed2 <= upperBound, "Gas usage not within expected tolerance");

        vm.stopPrank();
    }

    /**
     * @notice Attempts to verify total supply changes if HLG truly burns supply and GAINS truly mints supply.
     *         For a real fork, HLG might not reduce total supply in the way a mock does. Adjust accordingly.
     */
    function test_ForkMigrateHLGToGAINS_TotalSupplyChecks() external {
        vm.startPrank(deployer);

        // If the real HLG on Sepolia does not implement a standard burn, this may not hold.
        // Attempt anyway for completeness.
        try IERC20(SEP_HLG).totalSupply() returns (uint256 preHLGSupply) {
            uint256 preGAINS = gains.totalSupply();
            uint256 amount = 1 ether;

            IERC20(SEP_HLG).approve(address(migration), amount);
            migration.migrate(amount);

            uint256 postGAINS = gains.totalSupply();

            // If HLG is truly burned, totalSupply might go down. If not, or if the token's totalSupply is static, it won't.
            // We won't assert on HLG supply because real mainnet tokens often don't reduce total supply on burn proxies.
            assertEq(postGAINS, preGAINS + amount, "GAINS totalSupply should increase by the migrated amount");
        } catch {
            // If calling totalSupply() reverts on the real contract, we simply skip that check.
        }

        vm.stopPrank();
    }

    /**
     * @notice Ensures that setting the migration contract to zero address reverts.
     */
    function test_ForkSetMigrationContract_RevertIfZeroAddress() external {
        // We already set it in setUp(). Let's deploy a new GAINS to test from scratch.
        GAINS freshGains = new GAINS("GAINS", "GAINS", address(endpoints[1]), address(this));

        vm.startPrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        freshGains.setMigrationContract(address(0));
        vm.stopPrank();
    }

    /**
     * @notice Tests that MigrationContractSet is emitted when setting the migration contract.
     *         We must deploy a fresh GAINS again to see this from zero to new address.
     */
    function test_ForkSetMigrationContract_EmitsEvent() external {
        GAINS freshGains = new GAINS("GAINS", "GAINS", address(endpoints[1]), address(this));

        vm.startPrank(address(this));

        vm.expectEmit(true, true, false, true);
        emit MigrationContractSet(address(migration));
        freshGains.setMigrationContract(address(migration));

        vm.stopPrank();
    }

    /**
     * @notice Tests that once the migration contract is set, it cannot be changed again.
     */
    function test_ForkSetMigrationContract_RevertIfAlreadySet() external {
        // Gains contract in setUp() is already set to migration
        vm.startPrank(address(this));

        // Try to set a second time
        vm.expectRevert(abi.encodeWithSignature("MigrationContractAlreadySet()"));
        gains.setMigrationContract(address(0xDEAD));

        vm.stopPrank();
    }

    /**
     * @notice Tests that migration reverts with BurnFromFailed when burnFrom fails,
     *         using fresh local instances of MockHLG, GAINS, and MigrateHLGToGAINS.
     */
    function test_ForkMigrateHLGToGAINS_Revert_BurnFromFailed() external {
        // Deploy a fresh instance of MockHLG to simulate burn failure.
        MockHLG localMockHLG = new MockHLG("Mock HLG", "HLG");
        // Mint tokens to the deployer.
        localMockHLG.mint(deployer, 10_000 ether);

        // Deploy a fresh GAINS instance (this one has no migration contract set yet).
        GAINS localGains = new GAINS("GAINS", "GAINS", address(endpoints[1]), address(this));

        // Deploy a new migration contract using the local MockHLG and local GAINS.
        MigrateHLGToGAINS localMigration = new MigrateHLGToGAINS(address(localMockHLG), address(localGains));
        // Set the migration contract in the fresh GAINS instance.
        localGains.setMigrationContract(address(localMigration));

        vm.startPrank(deployer);
        // Approve the migration contract to spend tokens.
        localMockHLG.approve(address(localMigration), 1000 ether);
        // Force burnFrom to return false.
        localMockHLG.setShouldBurnSucceed(false);

        // Expect the migration to revert with the custom error.
        vm.expectRevert(MigrateHLGToGAINS.BurnFromFailed.selector);
        localMigration.migrate(1000 ether);
        vm.stopPrank();

        // Reset the flag so other tests remain unaffected
        localMockHLG.setShouldBurnSucceed(true);
    }
}
