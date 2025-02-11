// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import "../src/MigrateHLGToGAINS.sol";

/// @title TransferOwnership Script
/// @notice Script to transfer ownership of the GAINS and MigrateHLGToGAINS contracts to a Gnosis Safe
contract TransferOwnership is Script {
    /// @notice Executes the ownership transfer
    /// @dev Reads GAINS_CONTRACT, MIGRATION_CONTRACT, GNOSIS_SAFE, and PRIVATE_KEY from environment variables
    function run() external {
        address GAINS_CONTRACT = vm.envAddress("GAINS_CONTRACT");
        address MIGRATION_CONTRACT = vm.envAddress("MIGRATION_CONTRACT");
        address GNOSIS_SAFE = vm.envAddress("GNOSIS_SAFE");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        require(GAINS_CONTRACT != address(0), "Invalid GAINS contract address");
        require(MIGRATION_CONTRACT != address(0), "Invalid Migration contract address");
        require(GNOSIS_SAFE != address(0), "Invalid Gnosis Safe address");

        console.log("Starting ownership transfer...");
        console.log("GAINS Contract:", GAINS_CONTRACT);
        console.log("Migration Contract:", MIGRATION_CONTRACT);
        console.log("New Owner (Gnosis Safe):", GNOSIS_SAFE);

        vm.startBroadcast(deployerPrivateKey);

        // Transfer ownership of GAINS
        GAINS gains = GAINS(GAINS_CONTRACT);
        address currentGainsOwner = gains.owner();
        console.log("Current GAINS owner:", currentGainsOwner);
        gains.transferOwnership(GNOSIS_SAFE);
        console.log("GAINS ownership transferred to:", GNOSIS_SAFE);

        // Transfer ownership of MigrateHLGToGAINS
        MigrateHLGToGAINS migration = MigrateHLGToGAINS(MIGRATION_CONTRACT);
        address currentMigrationOwner = migration.owner();
        console.log("Current Migration owner:", currentMigrationOwner);
        migration.transferOwnership(GNOSIS_SAFE);
        console.log("Migration ownership transferred to:", GNOSIS_SAFE);

        vm.stopBroadcast();

        console.log("Ownership transfer complete!");
        console.log("New owner is now:", GNOSIS_SAFE);
    }
}
