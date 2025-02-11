// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/GAINS.sol";

/// @title TransferOwnership Script
/// @notice Script to transfer ownership of the GAINS contract to a Gnosis Safe
contract TransferOwnership is Script {
    /// @notice Executes the ownership transfer
    /// @dev Reads GAINS_CONTRACT and GNOSIS_SAFE addresses from environment variables
    function run() external {
        address GAINS_CONTRACT = vm.envAddress("GAINS_CONTRACT");
        address GNOSIS_SAFE = vm.envAddress("GNOSIS_SAFE");

        require(GAINS_CONTRACT != address(0), "Invalid GAINS contract address");
        require(GNOSIS_SAFE != address(0), "Invalid Gnosis Safe address");

        console.log("Starting ownership transfer...");
        console.log("GAINS Contract:", GAINS_CONTRACT);
        console.log("New Owner (Gnosis Safe):", GNOSIS_SAFE);

        vm.startBroadcast();

        GAINS gains = GAINS(GAINS_CONTRACT);
        address currentOwner = gains.owner();
        console.log("Current owner:", currentOwner);

        gains.transferOwnership(GNOSIS_SAFE);

        vm.stopBroadcast();

        console.log("Ownership transfer complete!");
        console.log("New owner is now:", GNOSIS_SAFE);
    }
}
