// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import "../src/MigrateHLGToGAINS.sol";

/**
 * @title GetOwnershipScript
 * @notice Script to check ownership of GAINS and MigrateHLGToGAINS contracts
 */
contract GetOwnership is Script {
    /**
     * @notice Gets and displays ownership information for both contracts
     */
    function getOwnership() public view {
        // Load contract addresses from environment
        address gainsAddress = vm.envOr("GAINS_CONTRACT", address(0));
        address migrationAddress = vm.envOr("MIGRATION_CONTRACT", address(0));

        console.log("\n=== Contract Ownership Information ===");

        // Check GAINS contract ownership
        if (gainsAddress != address(0)) {
            GAINS gains = GAINS(gainsAddress);
            address gainsOwner = gains.owner();
            console.log("\nGAINS Contract");
            console.log("Address:", address(gains));
            console.log("Owner:", gainsOwner);
        } else {
            console.log("\nGAINS Contract address not set in environment");
        }

        // Check MigrateHLGToGAINS contract ownership
        if (migrationAddress != address(0)) {
            MigrateHLGToGAINS migrator = MigrateHLGToGAINS(migrationAddress);
            address migratorOwner = migrator.owner();
            console.log("\nMigrateHLGToGAINS Contract");
            console.log("Address:", address(migrator));
            console.log("Owner:", migratorOwner);
        } else {
            console.log("\nMigrator Contract address not set in environment");
        }
    }

    function run() public view {
        getOwnership();
    }
}
