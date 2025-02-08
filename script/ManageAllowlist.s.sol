// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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
     * @notice Generic helper to parse an array of addresses from a JSON file.
     * @param jsonPath Path to the JSON file (e.g., "./allowlist.json")
     * @param key The JSON key under which the address array is stored (e.g., "allowlist")
     */
    function _readAddressesFromJson(
        string memory jsonPath,
        string memory key
    ) internal view returns (address[] memory accounts) {
        // Read entire file as string
        string memory fileContent = vm.readFile(jsonPath);

        // Parse the JSON for the given key and decode it into address[]
        bytes memory raw = vm.parseJson(fileContent, key);
        accounts = abi.decode(raw, (address[]));
    }

    /**
     * @notice Add addresses from a JSON file to the allowlist.
     * @param jsonPath Path to the JSON file.
     * @param key The JSON key with an array of addresses.
     */
    function addAddressesFromJson(string memory jsonPath, string memory key) external {
        MigrateHLGToGAINS migration = getMigrationContract();

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        address[] memory accounts = _readAddressesFromJson(jsonPath, key);
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
     * @notice Remove addresses from a JSON file to the allowlist.
     * @param jsonPath Path to the JSON file.
     * @param key The JSON key with an array of addresses.
     */
    function removeAddressesFromJson(string memory jsonPath, string memory key) external {
        MigrateHLGToGAINS migration = getMigrationContract();

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        address[] memory accounts = _readAddressesFromJson(jsonPath, key);
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
