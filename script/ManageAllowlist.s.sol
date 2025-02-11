// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/MigrateHLGToGAINS.sol";

/**
 * @title ManageAllowlist
 * @notice A Foundry script for managing the allowlist of MigrateHLGToGAINS.
 *
 * Usage examples:
 *
 * 1) Add addresses from a JSON file:
 *    forge script script/ManageAllowlist.s.sol:ManageAllowlist \
 *      --sig "addAddressesFromJson(string,string)" "('./allowlist.json','allowlist')" \
 *      --rpc-url <YOUR_RPC> --broadcast
 *
 * 2) Remove addresses from a JSON file:
 *    forge script script/ManageAllowlist.s.sol:ManageAllowlist \
 *      --sig "removeAddressesFromJson(string,string)" "('./allowlist.json','allowlist')" \
 *      --rpc-url <YOUR_RPC> --broadcast
 *
 * 3) Enable or disable the allowlist:
 *    forge script script/ManageAllowlist.s.sol:ManageAllowlist \
 *      --sig "deactivateAllowlist()" \
 *      --rpc-url <YOUR_RPC> --broadcast
 *
 * Make `MIGRATION_CONTRACT` and `PRIVATE_KEY` set in .env
 */
contract ManageAllowlist is Script {
    /**
     * @dev Reads MIGRATION_CONTRACT + PRIVATE_KEY from .env
     */
    function getMigrationContract() internal view returns (MigrateHLGToGAINS migration) {
        address migrationAddress = vm.envAddress("MIGRATION_CONTRACT");
        migration = MigrateHLGToGAINS(migrationAddress);
    }

    /**
     * @notice Reads an array of addresses from a JSON file.
     * @param jsonFilename The name of the JSON file (e.g., "allowlist.json").
     * @param key The JSON key under which the address array is stored (e.g., "allowlist").
     */
    function _readAddressesFromJson(
        string memory jsonFilename,
        string memory key
    ) internal view returns (address[] memory accounts) {
        // Get absolute file path using Foundry's project root
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/", jsonFilename);

        // Read JSON file content
        string memory json = vm.readFile(path);

        // Parse and decode JSON data.
        // Prepend "$." to the key to form a valid JSONPath (e.g., "$.allowlist")
        bytes memory raw = vm.parseJson(json, string.concat("$.", key));
        accounts = abi.decode(raw, (address[]));
    }

    /**
     * @notice Add addresses from a JSON file to the allowlist.
     * @param jsonFilename Name of the JSON file (e.g., "allowlist.json").
     * @param key The JSON key with an array of addresses.
     */
    function addAddressesFromJson(string memory jsonFilename, string memory key) external {
        MigrateHLGToGAINS migration = getMigrationContract();

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        address[] memory accounts = _readAddressesFromJson(jsonFilename, key);
        uint256 len = accounts.length;

        for (uint256 i = 0; i < len; ) {
            migration.addToAllowlist(accounts[i]);
            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();
    }

    /**
     * @notice Remove addresses from a JSON file from the allowlist.
     * @param jsonFilename Name of the JSON file (e.g., "allowlist.json").
     * @param key The JSON key with an array of addresses.
     */
    function removeAddressesFromJson(string memory jsonFilename, string memory key) external {
        MigrateHLGToGAINS migration = getMigrationContract();

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        address[] memory accounts = _readAddressesFromJson(jsonFilename, key);
        uint256 len = accounts.length;

        for (uint256 i = 0; i < len; ) {
            migration.removeFromAllowlist(accounts[i]);
            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();
    }

    /**
     * @notice Disable the entire allowlist.
     */
    function deactivateAllowlist() external {
        MigrateHLGToGAINS migration = getMigrationContract();

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        migration.deactivateAllowlist();

        vm.stopBroadcast();
    }
}
