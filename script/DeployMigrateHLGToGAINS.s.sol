// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import "../src/MigrateHLGToGAINS.sol";

/**
 * @title DeployMigrateHLGToGAINS
 * @notice Deploys GAINS + MigrateHLGToGAINS via CREATE2, or reuses them if already deployed.
 *
 * Usage:
 *   forge script script/DeployMigrateHLGToGAINS.s.sol:DeployMigrateHLGToGAINS \
 *       --rpc-url $RPC_URL \
 *       --broadcast \
 *       --verify \
 *       -vvvv
 *
 * Foundry will attempt to verify automatically if you provide:
 *   - ETHERSCAN_API_KEY in your env
 *   - matching compiler version, etc.
 */
contract DeployMigrateHLGToGAINS is Script {
    // GAINS name and symbol
    string public constant GAINS_NAME = "GAINS";
    string public constant GAINS_SYMBOL = "GAINS";

    // Example: For Sepolia
    address public constant LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address public constant GAINS_OWNER = 0x5f5C3548f96C7DA33A18E5F2F2f13519e1c8bD0d; // e.g. your deployer or Gnosis safe
    address public constant HLG_ADDRESS = 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1; // Deployed HLG on this chain

    // CREATE2 salts
    bytes32 public constant SALT_GAINS = bytes32(uint256(keccak256("GAINS_V1")));
    bytes32 public constant SALT_MIGRATION = bytes32(uint256(keccak256("MIGRATION_V1")));

    /**
    /**
    * @notice Check if an address has deployed code
    */
    function hasCode(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    /**
    * @dev Helper function to deploy bytecode using CREATE2
    */
    function deployBytecode(uint256 value, bytes memory bytecode, bytes32 salt) internal returns (address addr) {
        assembly {
            addr := create2(value, add(bytecode, 0x20), mload(bytecode), salt)
        }
    }

    /**
     * @notice Main entrypoint. Idempotently deploy or reuse GAINS and MigrateHLGToGAINS, then set references.
     */
    function run() external {
        // 1) Load the deployer's private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 2) Start broadcast so subsequent calls are real tx's
        vm.startBroadcast(deployerPrivateKey);

        // 3) Compute the expected addresses
        //    If code is present, skip deployment
        //    If not, deploy via CREATE2
        // GAINS
        bytes memory gainsConstructorArgs = abi.encode(GAINS_NAME, GAINS_SYMBOL, LZ_ENDPOINT, GAINS_OWNER);
        bytes memory gainsBytecode = abi.encodePacked(type(GAINS).creationCode, gainsConstructorArgs);
        address gainsAddr = computeCreate2Address(
            SALT_GAINS,
            keccak256(gainsBytecode),
            address(this)
        );

        GAINS gains;
        if (!hasCode(gainsAddr)) {
            console.log("Deploying GAINS via CREATE2 at:", gainsAddr);
            address deployedAddr = deployBytecode(0, gainsBytecode, SALT_GAINS);
            require(deployedAddr != address(0), "CREATE2 GAINS failed");
            gains = GAINS(deployedAddr);
            console.log("Deployed GAINS at:", address(gains));
        } else {
            console.log("GAINS already deployed at:", gainsAddr);
            gains = GAINS(gainsAddr);
        }

        // MIGRATION
        bytes memory migrationConstructorArgs = abi.encode(HLG_ADDRESS, address(gains));
        bytes memory migrationBytecode = abi.encodePacked(
            type(MigrateHLGToGAINS).creationCode,
            migrationConstructorArgs
        );
        address migrationAddr = computeCreate2Address(
            SALT_MIGRATION,
            keccak256(migrationBytecode),
            address(this)
        );

        MigrateHLGToGAINS migration;
        if (!hasCode(migrationAddr)) {
            console.log("Deploying MigrateHLGToGAINS via CREATE2 at:", migrationAddr);
            address deployedAddr = deployBytecode(0, migrationBytecode, SALT_MIGRATION);
            require(deployedAddr != address(0), "CREATE2 Migration failed");
            migration = MigrateHLGToGAINS(deployedAddr);
            console.log("Deployed MigrateHLGToGAINS at:", address(migration));
        } else {
            console.log("MigrateHLGToGAINS already deployed at:", migrationAddr);
            migration = MigrateHLGToGAINS(migrationAddr);
        }

        // 4) Set Gains -> Migration reference if needed
        if (gains.migrationContract() != address(migration)) {
            gains.setMigrationContract(address(migration));
            console.log("GAINS.migrationContract set to:", address(migration));
        }

        // 5) Stop broadcasting
        vm.stopBroadcast();

        // 6) Log final addresses
        console.log("\nFinal addresses:");
        console.log("GAINS:", address(gains));
        console.log("MigrateHLGToGAINS:", address(migration));

        console.log("Done. If you ran with --verify, Foundry will attempt to verify automatically.");
    }
}
