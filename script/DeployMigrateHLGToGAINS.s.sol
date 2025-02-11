// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import "../src/MigrateHLGToGAINS.sol";

/**
 * @title DeployMigrateHLGToGAINS
 * @notice Uses Foundry’s built-in deterministic deployer for CREATE2 at 0x4e59b44847b379578588920cA78FbF26c0B4956C.
 */
contract DeployMigrateHLGToGAINS is Script {
    // The Foundry deterministic deployer address (same across all EVM chains)
    address internal constant FOUNDRY_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // CREATE2 salts
    bytes32 public constant SALT_GAINS = keccak256("GAINS_V1");
    bytes32 public constant SALT_MIGRATION = keccak256("MIGRATION_V1");

    /**
     * @notice Check if an address already has deployed code.
     */
    function hasCode(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    /**
     * @dev Compute the address for deterministic deployment using Foundry's deployer.
     */
    function computeFoundryCreate2Address(bytes32 salt, bytes memory initCode) internal pure returns (address) {
        bytes32 codeHash = keccak256(initCode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), FOUNDRY_DEPLOYER, salt, codeHash));
        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Main deployment entrypoint. Deploys or reuses contracts deterministically.
     */
    function run() external {
        string memory GAINS_NAME = "GAINS";
        string memory GAINS_SYMBOL = "GAINS";

        // Load constants from .env
        address LZ_ENDPOINT = vm.envAddress("LZ_ENDPOINT");
        address GAINS_OWNER = vm.envAddress("GAINS_OWNER");
        address HLG_ADDRESS = vm.envAddress("HLG_ADDRESS");

        // Load deployer's private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // ---------------------------
        // Deploy/Re-use GAINS
        // ---------------------------
        bytes memory gainsConstructorArgs = abi.encode(GAINS_NAME, GAINS_SYMBOL, LZ_ENDPOINT, GAINS_OWNER);
        bytes memory gainsInitCode = abi.encodePacked(type(GAINS).creationCode, gainsConstructorArgs);

        address gainsPredicted = computeFoundryCreate2Address(SALT_GAINS, gainsInitCode);

        GAINS gains;
        if (!hasCode(gainsPredicted)) {
            console.log("Deterministically deploying GAINS at:", gainsPredicted);
            gains = new GAINS{salt: SALT_GAINS}(GAINS_NAME, GAINS_SYMBOL, LZ_ENDPOINT, GAINS_OWNER);
            console.log("GAINS deployed at:", address(gains));
            require(address(gains) == gainsPredicted, "GAINS address mismatch");
        } else {
            console.log("GAINS already at:", gainsPredicted);
            gains = GAINS(gainsPredicted);
        }

        // ---------------------------
        // Deploy/Re-use MigrateHLGToGAINS
        // ---------------------------
        bytes memory migrationConstructorArgs = abi.encode(HLG_ADDRESS, gainsPredicted, GAINS_OWNER);
        bytes memory migrationInitCode = abi.encodePacked(
            type(MigrateHLGToGAINS).creationCode,
            migrationConstructorArgs
        );

        address migrationPredicted = computeFoundryCreate2Address(SALT_MIGRATION, migrationInitCode);

        MigrateHLGToGAINS migration;
        if (!hasCode(migrationPredicted)) {
            console.log("Deterministically deploying MigrateHLGToGAINS at:", migrationPredicted);
            migration = new MigrateHLGToGAINS{salt: SALT_MIGRATION}(HLG_ADDRESS, gainsPredicted, GAINS_OWNER);
            console.log("MigrateHLGToGAINS deployed at:", address(migration));
            require(address(migration) == migrationPredicted, "Migration address mismatch");
        } else {
            console.log("MigrateHLGToGAINS already at:", migrationPredicted);
            migration = MigrateHLGToGAINS(migrationPredicted);
        }

        // ---------------------------
        // Link them if needed
        // ---------------------------
        if (gains.migrationContract() == address(0)) {
            gains.setMigrationContract(address(migration));
            console.log("Set GAINS.migrationContract to:", address(migration));
        } else {
            console.log("GAINS.migrationContract is already set to:", gains.migrationContract());
        }

        vm.stopBroadcast();

        // Final log output
        console.log("\nFinal addresses:");
        console.log("GAINS:", address(gains));
        console.log("MigrateHLGToGAINS:", address(migration));
        console.log("Done. If run with --verify, Foundry will attempt to auto-verify newly deployed contracts only.");
    }
}
