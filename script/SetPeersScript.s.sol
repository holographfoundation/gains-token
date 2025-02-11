// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

/**
 * @title SetPeersScript
 * @notice Script to set peers for the OFT contracts across multiple chains, supporting testnet and mainnet.
 * Defaults to testnet unless "MAINNET" is set to true.
 */
contract SetPeersScript is Script {
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
     * @dev Converts an address to bytes32.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /**
     * @dev Initializes endpoint IDs and contract addresses based on mainnet or testnet mode.
     */
    function initializeConfig() internal {
        bool mainnet = vm.envBool("MAINNET"); // Defaults to false if not set

        if (mainnet) {
            // Mainnet configuration
            ETHEREUM_EID = ETHEREUM_MAINNET_EID;
            POLYGON_EID = POLYGON_MAINNET_EID;
            BASE_EID = BASE_MAINNET_EID;
            BSC_EID = BSC_MAINNET_EID;
            ARBITRUM_EID = ARBITRUM_MAINNET_EID;

            // TODO: Add mainnet addresses once deployed
            GAINS_CONTRACT = 0x0000000000000000000000000000000000000000;
        } else {
            // Testnet configuration
            ETHEREUM_EID = ETHEREUM_SEPOLIA_EID;
            POLYGON_EID = POLYGON_TESTNET_EID;
            BASE_EID = BASE_SEPOLIA_EID;
            BSC_EID = BSC_TESTNET_EID;
            ARBITRUM_EID = ARBITRUM_TESTNET_EID;

            // TODO: Update with final testnet addresses once deployed
            GAINS_CONTRACT = 0x2809443F5Ec9D648e9127fE7fFE7EA28C402d3b8;
        }
    }

    /**
     * @notice Sets peers for the OFT contracts across all chains.
     * @dev Must be called on each chain separately using the appropriate RPC URL.
     */
    function setPeers() public {
        initializeConfig();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Set peers for GAINS_CONTRACT on Ethereum
        IOAppCore(GAINS_CONTRACT).setPeer(POLYGON_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(BASE_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(BSC_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(ARBITRUM_EID, addressToBytes32(GAINS_CONTRACT));

        // Set peers for GAINS_CONTRACT on Polygon
        IOAppCore(GAINS_CONTRACT).setPeer(ETHEREUM_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(BASE_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(BSC_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(ARBITRUM_EID, addressToBytes32(GAINS_CONTRACT));

        // Set peers for GAINS_CONTRACT on Base
        IOAppCore(GAINS_CONTRACT).setPeer(ETHEREUM_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(POLYGON_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(BSC_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(ARBITRUM_EID, addressToBytes32(GAINS_CONTRACT));

        // Set peers for GAINS_CONTRACT on BSC
        IOAppCore(GAINS_CONTRACT).setPeer(ETHEREUM_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(POLYGON_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(BASE_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(ARBITRUM_EID, addressToBytes32(GAINS_CONTRACT));

        // Set peers for GAINS_CONTRACT on Arbitrum
        IOAppCore(GAINS_CONTRACT).setPeer(ETHEREUM_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(POLYGON_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(BASE_EID, addressToBytes32(GAINS_CONTRACT));
        IOAppCore(GAINS_CONTRACT).setPeer(BSC_EID, addressToBytes32(GAINS_CONTRACT));

        vm.stopBroadcast();

        console.log("Peers set successfully across all chains.");
    }

    /**
     * @notice Run function that only sets peers.
     */
    function run() public {
        setPeers();
    }
}
