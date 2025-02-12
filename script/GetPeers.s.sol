// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

/**
 * @title GetPeers
 * @notice Script to verify peer settings for the OFT contracts across multiple chains
 */
contract GetPeers is Script {
    // LayerZero Endpoint IDs (EIDs)
    uint32 constant ETHEREUM_MAINNET_EID = 30101;
    uint32 constant ETHEREUM_SEPOLIA_EID = 40161;
    uint32 constant BASE_MAINNET_EID = 30184;
    uint32 constant BASE_SEPOLIA_EID = 40245;
    uint32 constant BSC_MAINNET_EID = 30102;
    uint32 constant BSC_TESTNET_EID = 40102;
    uint32 constant ARBITRUM_MAINNET_EID = 30110;
    uint32 constant ARBITRUM_TESTNET_EID = 40231;
    uint32 constant POLYGON_MAINNET_EID = 30109;
    uint32 constant POLYGON_TESTNET_EID = 40267;

    // Contract addresses
    address GAINS_CONTRACT;

    uint32 ETHEREUM_EID;
    uint32 BASE_EID;
    uint32 BSC_EID;
    uint32 ARBITRUM_EID;
    uint32 POLYGON_EID;

    /**
     * @dev Converts bytes32 to address
     */
    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }

    /**
     * @dev Initializes endpoint IDs and contract addresses based on mainnet or testnet mode
     */
    function initializeConfig() internal {
        bool mainnet = vm.envBool("MAINNET"); // Defaults to false if not set

        // TODO: Ensure GAINS_CONTRACT is set in .env for the correct deployment
        if (vm.envAddress("GAINS_CONTRACT") == address(0)) {
            revert("GAINS_CONTRACT is not set in .env");
        }

        GAINS_CONTRACT = vm.envAddress("GAINS_CONTRACT");

        if (mainnet) {
            // Mainnet configuration
            ETHEREUM_EID = ETHEREUM_MAINNET_EID;
            POLYGON_EID = POLYGON_MAINNET_EID;
            BASE_EID = BASE_MAINNET_EID;
            BSC_EID = BSC_MAINNET_EID;
            ARBITRUM_EID = ARBITRUM_MAINNET_EID;
        } else {
            // Testnet configuration
            ETHEREUM_EID = ETHEREUM_SEPOLIA_EID;
            POLYGON_EID = POLYGON_TESTNET_EID;
            BASE_EID = BASE_SEPOLIA_EID;
            BSC_EID = BSC_TESTNET_EID;
            ARBITRUM_EID = ARBITRUM_TESTNET_EID;
        }
    }

    /**
     * @notice Gets and displays peer configurations for the current chain
     */
    function getPeers() public {
        initializeConfig();

        console.log("\n=== Peer Configuration for GAINS Contract ===");
        console.log("Contract Address:", GAINS_CONTRACT);

        // Get and display peer for each chain
        bytes32 ethereumPeer = IOAppCore(GAINS_CONTRACT).peers(ETHEREUM_EID);
        bytes32 polygonPeer = IOAppCore(GAINS_CONTRACT).peers(POLYGON_EID);
        bytes32 basePeer = IOAppCore(GAINS_CONTRACT).peers(BASE_EID);
        bytes32 bscPeer = IOAppCore(GAINS_CONTRACT).peers(BSC_EID);
        bytes32 arbitrumPeer = IOAppCore(GAINS_CONTRACT).peers(ARBITRUM_EID);

        console.log("\nPeer Configurations:");
        console.log("Ethereum (EID %s): %s", ETHEREUM_EID, bytes32ToAddress(ethereumPeer));
        console.log("Polygon (EID %s): %s", POLYGON_EID, bytes32ToAddress(polygonPeer));
        console.log("Base (EID %s): %s", BASE_EID, bytes32ToAddress(basePeer));
        console.log("BSC (EID %s): %s", BSC_EID, bytes32ToAddress(bscPeer));
        console.log("Arbitrum (EID %s): %s", ARBITRUM_EID, bytes32ToAddress(arbitrumPeer));
    }

    /**
     * @notice Run function that gets peers
     */
    function run() public {
        getPeers();
    }
}
