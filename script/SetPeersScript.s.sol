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
    uint32 constant AVAX_MAINNET_EID = 30106;
    uint32 constant AVAX_FUJI_EID = 40106;
    uint32 constant BASE_MAINNET_EID = 30184;
    uint32 constant BASE_SEPOLIA_EID = 40245;
    uint32 constant BSC_MAINNET_EID = 30102;
    uint32 constant BSC_TESTNET_EID = 40102;
    uint32 constant ARBITRUM_MAINNET_EID = 30110;
    uint32 constant ARBITRUM_TESTNET_EID = 40231;

    // Contract addresses
    address GAINS_ETHEREUM;
    address GAINS_AVALANCHE;
    address GAINS_BASE;
    address GAINS_BSC;
    address GAINS_ARBITRUM;

    uint32 ETHEREUM_EID;
    uint32 AVALANCHE_EID;
    uint32 BASE_EID;
    uint32 BSC_EID;
    uint32 ARBITRUM_EID;

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
            AVALANCHE_EID = AVAX_MAINNET_EID;
            BASE_EID = BASE_MAINNET_EID;
            BSC_EID = BSC_MAINNET_EID;
            ARBITRUM_EID = ARBITRUM_MAINNET_EID;

            // TODO: Add mainnet addresses once deployed
            GAINS_ETHEREUM = 0x0000000000000000000000000000000000000000;
            GAINS_AVALANCHE = 0x0000000000000000000000000000000000000000;
            GAINS_BASE = 0x0000000000000000000000000000000000000000;
            GAINS_BSC = 0x0000000000000000000000000000000000000000;
            GAINS_ARBITRUM = 0x0000000000000000000000000000000000000000;
        } else {
            // Testnet configuration
            ETHEREUM_EID = ETHEREUM_SEPOLIA_EID;
            AVALANCHE_EID = AVAX_FUJI_EID;
            BASE_EID = BASE_SEPOLIA_EID;
            BSC_EID = BSC_TESTNET_EID;
            ARBITRUM_EID = ARBITRUM_TESTNET_EID;

            // TODO: Update with final testnet addresses once deployed
            GAINS_ETHEREUM = 0x27ab1eF46295406d2190f7DbC4cDCFe6590CE076;
            GAINS_AVALANCHE = 0x27ab1eF46295406d2190f7DbC4cDCFe6590CE076;
            GAINS_BASE = 0x27ab1eF46295406d2190f7DbC4cDCFe6590CE076;
            GAINS_BSC = 0x27ab1eF46295406d2190f7DbC4cDCFe6590CE076;
            GAINS_ARBITRUM = 0x27ab1eF46295406d2190f7DbC4cDCFe6590CE076;
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

        // Set peers for GAINS on Ethereum
        IOAppCore(GAINS_ETHEREUM).setPeer(AVALANCHE_EID, addressToBytes32(GAINS_AVALANCHE));
        IOAppCore(GAINS_ETHEREUM).setPeer(BASE_EID, addressToBytes32(GAINS_BASE));
        IOAppCore(GAINS_ETHEREUM).setPeer(BSC_EID, addressToBytes32(GAINS_BSC));
        IOAppCore(GAINS_ETHEREUM).setPeer(ARBITRUM_EID, addressToBytes32(GAINS_ARBITRUM));

        // Set peers for GAINS on Avalanche
        IOAppCore(GAINS_AVALANCHE).setPeer(ETHEREUM_EID, addressToBytes32(GAINS_ETHEREUM));
        IOAppCore(GAINS_AVALANCHE).setPeer(BASE_EID, addressToBytes32(GAINS_BASE));
        IOAppCore(GAINS_AVALANCHE).setPeer(BSC_EID, addressToBytes32(GAINS_BSC));
        IOAppCore(GAINS_AVALANCHE).setPeer(ARBITRUM_EID, addressToBytes32(GAINS_ARBITRUM));

        // Set peers for GAINS on Base
        IOAppCore(GAINS_BASE).setPeer(ETHEREUM_EID, addressToBytes32(GAINS_ETHEREUM));
        IOAppCore(GAINS_BASE).setPeer(AVALANCHE_EID, addressToBytes32(GAINS_AVALANCHE));
        IOAppCore(GAINS_BASE).setPeer(BSC_EID, addressToBytes32(GAINS_BSC));
        IOAppCore(GAINS_BASE).setPeer(ARBITRUM_EID, addressToBytes32(GAINS_ARBITRUM));

        // Set peers for GAINS on BSC
        IOAppCore(GAINS_BSC).setPeer(ETHEREUM_EID, addressToBytes32(GAINS_ETHEREUM));
        IOAppCore(GAINS_BSC).setPeer(AVALANCHE_EID, addressToBytes32(GAINS_AVALANCHE));
        IOAppCore(GAINS_BSC).setPeer(BASE_EID, addressToBytes32(GAINS_BASE));
        IOAppCore(GAINS_BSC).setPeer(ARBITRUM_EID, addressToBytes32(GAINS_ARBITRUM));

        // Set peers for GAINS on Arbitrum
        IOAppCore(GAINS_ARBITRUM).setPeer(ETHEREUM_EID, addressToBytes32(GAINS_ETHEREUM));
        IOAppCore(GAINS_ARBITRUM).setPeer(AVALANCHE_EID, addressToBytes32(GAINS_AVALANCHE));
        IOAppCore(GAINS_ARBITRUM).setPeer(BASE_EID, addressToBytes32(GAINS_BASE));
        IOAppCore(GAINS_ARBITRUM).setPeer(BSC_EID, addressToBytes32(GAINS_BSC));

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
