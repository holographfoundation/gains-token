// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/GAINS.sol";
import { IOAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

/**
 * @title SetPeersScript
 * @notice Script to set peers for the OFT contracts on both chains.
 * Run with:
 * forge script script/SetPeersScript.s.sol:SetPeersScript --rpc-url <rpc-url> --broadcast -vvvv
 */
contract SetPeersScript is Script {
    // LayerZero Chain IDs
    uint32 constant ETH_SEPOLIA_CHAIN_ID = 40161; // Update to real LayerZero chain ID
    uint32 constant BASE_SEPOLIA_CHAIN_ID = 40245; // Update to real LayerZero chain ID

    // Contract addresses
    address constant GAINS_ETH_SEPOLIA = 0x354B7DEb6f6aa08a683461d5a6451E22458b17Ee;
    address constant GAINS_BASE_SEPOLIA = 0x354B7DEb6f6aa08a683461d5a6451E22458b17Ee;

    /**
     * @dev Converts an address to bytes32.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /**
     * @notice Sets peers for the OFT contracts on both chains.
     * @dev Must be called on each chain separately using the appropriate RPC URL.
     */
    function setPeers() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Set peer for GAINS on ETH Sepolia to point to GAINS on Base Sepolia
        IOAppCore(GAINS_ETH_SEPOLIA).setPeer(BASE_SEPOLIA_CHAIN_ID, addressToBytes32(GAINS_BASE_SEPOLIA));

        // Set peer for GAINS on Base Sepolia to point to GAINS on ETH Sepolia
        IOAppCore(GAINS_BASE_SEPOLIA).setPeer(ETH_SEPOLIA_CHAIN_ID, addressToBytes32(GAINS_ETH_SEPOLIA));

        vm.stopBroadcast();

        console.log("Peers set successfully on both chains");
    }

    /**
     * @notice Example run function that only sets peers.
     */
    function run() public {
        setPeers();
    }
}
