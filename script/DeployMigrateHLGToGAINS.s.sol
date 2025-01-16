// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import "../src/MigrateHLGToGAINS.sol";

/**
 * @title DeployMigrateHLGToGAINS
 * @notice Uses Foundry’s built-in deterministic deployer at 0x4e59b448... to do `new ... { salt: ... }()`.
 *
 * Steps:
 * 1) Checks if GAINS & MigrateHLGToGAINS code already exist at the predicted addresses.
 * 2) If not, calls `new GAINS{salt: SALT_GAINS}(...)`.
 * 3) If code already exists, skip re-deployment.
 * 4) If run with --verify, Foundry attempts auto-verification for newly deployed contracts.
 *
 * Usage example:
 *   forge script script/DeployMigrateHLGToGAINS.s.sol:DeployMigrateHLGToGAINS \
 *       --rpc-url $RPC_URL \
 *       --broadcast \
 *       --verify \
 *       -vvvv
 */
contract DeployMigrateHLGToGAINS is Script {
    // The Foundry deterministic deployer address (same across all EVM chains)
    // Reference: https://book.getfoundry.sh/tutorials/create2
    address internal constant FOUNDRY_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // GAINS name/symbol
    string public constant GAINS_NAME = "GAINS";
    string public constant GAINS_SYMBOL = "GAINS";

    // Example: For Sepolia
    address public constant LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address public constant GAINS_OWNER = 0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d;
    address public constant HLG_ADDRESS = 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1;

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
     * @dev Foundry ephemeral deterministic deployer address is `FOUNDRY_DEPLOYER`.
     * We compute:
     *   keccak256( 0xff, FOUNDRY_DEPLOYER, salt, keccak256(init_code) )
     * Then take the low 20 bytes, after skipping the first 12 bytes of the 32-byte hash.
     *
     * For a contract created by:
     *   new MyContract{salt: salt}(constructorArgs)
     */
    function computeFoundryCreate2Address(bytes32 salt, bytes memory initCode) internal pure returns (address) {
        bytes32 codeHash = keccak256(initCode);
        // same formula: keccak256(0xff ++ foundryDeployer ++ salt ++ keccak256(initCode))
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), FOUNDRY_DEPLOYER, salt, codeHash));
        return address(uint160(uint256(hash)));
    }

    function run() external {
        // 1) Load private key from .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // ---------------------------
        // Deploy/Re-use GAINS
        // ---------------------------
        bytes memory gainsConstructorArgs = abi.encode(GAINS_NAME, GAINS_SYMBOL, LZ_ENDPOINT, GAINS_OWNER);
        // The final creation code that the deterministic deployer uses
        // is `type(GAINS).creationCode` concatenated with the constructor args
        bytes memory gainsInitCode = abi.encodePacked(type(GAINS).creationCode, gainsConstructorArgs);

        address gainsPredicted = computeFoundryCreate2Address(SALT_GAINS, gainsInitCode);

        GAINS gains;
        if (!hasCode(gainsPredicted)) {
            console.log("Deterministically deploying GAINS at:", gainsPredicted);
            // Deploy by calling `new GAINS{salt: SALT_GAINS}(...args...)`
            gains = new GAINS{ salt: SALT_GAINS }(GAINS_NAME, GAINS_SYMBOL, LZ_ENDPOINT, GAINS_OWNER);
            console.log("GAINS deployed at:", address(gains));
            require(address(gains) == gainsPredicted, "GAINS address mismatch");
        } else {
            console.log("GAINS already at:", gainsPredicted);
            gains = GAINS(gainsPredicted);
        }

        // ---------------------------
        // Deploy/Re-use MigrateHLGToGAINS
        // ---------------------------
        bytes memory migrationConstructorArgs = abi.encode(HLG_ADDRESS, gainsPredicted);
        bytes memory migrationInitCode = abi.encodePacked(
            type(MigrateHLGToGAINS).creationCode,
            migrationConstructorArgs
        );
        address migrationPredicted = computeFoundryCreate2Address(SALT_MIGRATION, migrationInitCode);

        MigrateHLGToGAINS migration;
        if (!hasCode(migrationPredicted)) {
            console.log("Deterministically deploying MigrateHLGToGAINS at:", migrationPredicted);
            // `new` with salt
            migration = new MigrateHLGToGAINS{ salt: SALT_MIGRATION }(HLG_ADDRESS, gainsPredicted);
            console.log("MigrateHLGToGAINS deployed at:", address(migration));
            require(address(migration) == migrationPredicted, "Migration address mismatch");
        } else {
            console.log("MigrateHLGToGAINS already at:", migrationPredicted);
            migration = MigrateHLGToGAINS(migrationPredicted);
        }

        // ---------------------------
        // Link them if needed
        // ---------------------------
        if (gains.migrationContract() != address(migration)) {
            gains.setMigrationContract(address(migration));
            console.log("Set GAINS.migrationContract to:", address(migration));
        }

        vm.stopBroadcast();

        console.log("\nFinal addresses:");
        console.log("GAINS:", address(gains));
        console.log("MigrateHLGToGAINS:", address(migration));
        console.log("Done. If run with --verify, Foundry will attempt to auto-verify newly deployed contracts only.");
    }
}
