// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import "../src/MigrateHLGToGAINS.sol";

/**
 * @title DeployMigrateHLGToGAINS
 * @notice This Foundry script deploys GAINS + MigrateHLGToGAINS using CREATE2 for consistent addresses.
 *
 * Usage:
 *   forge script script/DeployMigrateHLGToGAINS.s.sol:DeployMigrateHLGToGAINS \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --verify \
 *     -vvvv
 */
contract DeployMigrateHLGToGAINS is Script {
    string public constant GAINS_NAME = "GAINS";
    string public constant GAINS_SYMBOL = "GAINS";

    // Fill in actual chain-specific values:
    address public constant LZ_ENDPOINT = 0x1234567890123456789012345678901234567890; // e.g. for the deployment chain
    address public constant GAINS_OWNER = 0x111122223333444455556666777788889999AAAA; // e.g. a Gnosis Safe

    // The deployed HLG address on the chain:
    address public constant HLG_ADDRESS = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // e.g. use env var

    // CREATE2 salt — must be consistent across all chains
    bytes32 public constant SALT_GAINS = keccak256("GAINS_SALT_V1");
    bytes32 public constant SALT_MIGRATION = keccak256("MIGRATE_HLG_TO_GAINS_V1");

    function run() external {
        // 1) Load private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 2) Start broadcasting
        vm.startBroadcast(deployerPrivateKey);

        // 3) Deploy GAINS via CREATE2
        //    GAINS constructor signature: (string memory, string memory, address, address)
        bytes memory gainsConstructorArgs = abi.encode(GAINS_NAME, GAINS_SYMBOL, LZ_ENDPOINT, GAINS_OWNER);
        bytes memory gainsBytecode = abi.encodePacked(type(GAINS).creationCode, gainsConstructorArgs);

        address gainsAddr;
        assembly {
            // Foundry cheatcode: create2(value, offset, size, salt)
            gainsAddr := create2(
                0, // no ETH value
                add(gainsBytecode, 0x20), // skip the length slot
                mload(gainsBytecode), // length of the bytecode
                SALT_GAINS // salt
            )
        }
        require(gainsAddr != address(0), "CREATE2 GAINS failed");
        GAINS gains = GAINS(gainsAddr);

        // 4) Deploy MigrateHLGToGAINS via CREATE2
        //    MigrateHLGToGAINS constructor signature: (address, address)
        bytes memory migrationConstructorArgs = abi.encode(HLG_ADDRESS, gainsAddr);
        bytes memory migrationBytecode = abi.encodePacked(
            type(MigrateHLGToGAINS).creationCode,
            migrationConstructorArgs
        );

        address migrationAddr;
        assembly {
            migrationAddr := create2(0, add(migrationBytecode, 0x20), mload(migrationBytecode), SALT_MIGRATION)
        }
        require(migrationAddr != address(0), "CREATE2 Migration failed");
        MigrateHLGToGAINS migration = MigrateHLGToGAINS(migrationAddr);

        // 5) Set GainsMigration as the migration contract
        gains.setMigrationContract(migrationAddr);

        // 6) End broadcast
        vm.stopBroadcast();

        // Log addresses
        console.log("GAINS deployed at:", gainsAddr);
        console.log("MigrateHLGToGAINS deployed at:", migrationAddr);
    }
}
