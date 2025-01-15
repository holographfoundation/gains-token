// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../src/GAINS.sol";
import "../../src/MigrateToGAINS.sol";

/**
 * @title MigrateToGAINSFork
 * @notice Demonstrates how to fork Sepolia to test HLG -> GAINS migration in a more realistic environment.
 *
 */
contract MigrateToGAINSFork is TestHelperOz5 {
    // The HLG proxy (HolographUtilityToken) address on Sepolia
    address internal constant SEP_HLG = 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1;

    // We'll deploy our own GAINS + MigrateToGAINS on the fork
    GAINS internal gains;
    MigrateToGAINS internal migration;

    // The address of the deployer of HolographUtilityToken on Sepolia (holds HLG so we can test migration)
    address internal deployer = 0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d;

    function setUp() public override {
        super.setUp();

        // 1) Select/fork Sepolia at a recent block
        //    In foundry.toml or CLI, specify `--fork-url` or set env `SEPOLIA_RPC_URL`.
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));

        // Setup LayerZero endpoints
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // 2) Deploy your GAINS contract on this fork
        //    We can set the "owner" to our own address or some test address.
        gains = new GAINS("GAINS", "GAINS", address(endpoints[1]), address(this));

        // 3) Deploy the MigrateToGAINS contract pointing at the *real* Sepolia HLG address
        migration = new MigrateToGAINS(SEP_HLG, address(gains));

        // 4) As GAINS owner, set the migration contract
        gains.setMigrationContract(address(migration));

        // We label addresses for clarity in trace
        vm.label(SEP_HLG, "SepoliaHLG");
        vm.label(address(gains), "GAINS");
        vm.label(address(migration), "MigrateToGAINS");
        vm.label(deployer, "deployer");
    }

    /**
     * @notice Attempt a migration from real HLG on Sepolia. If the real HLG requires `onlySource()`,
     *         this may revert with "ERC20: source only call." If so, that's normal unless the real
     *         contract is configured to allow external `sourceBurn`.
     */
    function testForkMigrateHLG() external {
        // 1) Check initial HLG balance
        uint256 deployerHLGBal = IERC20(SEP_HLG).balanceOf(deployer);
        console.log("Initial HLG balance:", deployerHLGBal);

        // Use 1 HLG (18 decimals) for testing
        uint256 hlgAmount = 1 * 10 ** 18; // 1 HLG token
        console.log("Amount to migrate (in HLG wei):", hlgAmount);

        // 2) Approve the migration contract
        vm.startPrank(deployer);

        IERC20(SEP_HLG).approve(address(migration), hlgAmount);
        console.log("Approved migration contract for HLG");

        uint256 allowance = IERC20(SEP_HLG).allowance(deployer, address(migration));
        console.log("Migration contract HLG allowance:", allowance);

        // Debug balance right before migration
        uint256 preBalance = IERC20(SEP_HLG).balanceOf(deployer);
        console.log("HLG balance before migration:", preBalance);

        // 3) Attempt the migration
        migration.migrate(hlgAmount);

        // 4) Debug what happened
        uint256 postBalance = IERC20(SEP_HLG).balanceOf(deployer);
        console.log("HLG balance after migration:", postBalance);

        uint256 deployerGainsBal = gains.balanceOf(deployer);
        console.log("GAINS balance after migration:", deployerGainsBal);

        vm.stopPrank();
    }
}
