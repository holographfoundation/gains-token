// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/GAINS.sol";

// For bridging calls (quoteSend, send)
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

// For setPeer (whitelisting) calls
import { IOAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract BridgeGAINSScript is Script {
    using OptionsBuilder for bytes; // For addExecutorLzReceiveOption()

    GAINS public gains;

    // Update these to the *correct* OApp Endpoint IDs for your chains
    uint32 constant ETH_SEPOLIA_CHAIN_ID = 40161;
    uint32 constant BASE_SEPOLIA_CHAIN_ID = 40245;

    // Addresses of your GAINS token on each chain
    address constant GAINS_ETH_SEPOLIA = 0x354B7DEb6f6aa08a683461d5a6451E22458b17Ee;
    address constant GAINS_BASE_SEPOLIA = 0x354B7DEb6f6aa08a683461d5a6451E22458b17Ee;

    function setUp() public {
        gains = GAINS(GAINS_ETH_SEPOLIA);
    }

    /**
     * @dev Converts an address to bytes32.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /**
     * @notice Whitelists peers on both chains so the OFT contracts can talk to each other.
     * @dev This function calls `setPeer` on each chain's OApp contract.
     *      In practice, you'd run this script once on each chain with the correct RPC, or call
     *      these setPeer functions within the contract on each respective chain.
     */
    function setPeers() public {
        // Get private key and verify owner
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address currentOwner = GAINS(GAINS_ETH_SEPOLIA).owner();
        require(deployerAddress == currentOwner, "Must be called by the owner");

        // Start broadcast with explicit private key
        vm.startBroadcast(deployerPrivateKey);

        // GAINS on ETH Sepolia: set the peer to GAINS on Base Sepolia
        IOAppCore(GAINS_ETH_SEPOLIA).setPeer(BASE_SEPOLIA_CHAIN_ID, addressToBytes32(GAINS_BASE_SEPOLIA));

        // GAINS on Base Sepolia: set the peer to GAINS on ETH Sepolia
        IOAppCore(GAINS_BASE_SEPOLIA).setPeer(ETH_SEPOLIA_CHAIN_ID, addressToBytes32(GAINS_ETH_SEPOLIA));

        vm.stopBroadcast();
        console.log("Peers set successfully on both chains");
    }

    /**
     * @notice Bridges `amount` of GAINS tokens from ETH Sepolia to Base Sepolia.
     * @param amount Amount of GAINS tokens (in wei).
     * @param recipient Recipient address on the destination chain (Base Sepolia).
     */
    function bridgeTokens(uint256 amount, address recipient) public {
        require(amount > 0, "Amount must be > 0");
        require(recipient != address(0), "Invalid recipient");

        // Get private key and verify owner
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address currentOwner = GAINS(GAINS_ETH_SEPOLIA).owner();
        require(deployerAddress == currentOwner, "Must be called by the owner");

        // Start broadcast with explicit private key
        vm.startBroadcast(deployerPrivateKey);
        // Approve bridging
        gains.approve(address(gains), amount);

        // Build LayerZero "extraOptions"
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);

        // Build SendParam
        SendParam memory sendParam = SendParam({
            dstEid: BASE_SEPOLIA_CHAIN_ID,
            to: addressToBytes32(recipient),
            amountLD: amount,
            minAmountLD: (amount * 90) / 100, // 90% slippage protection
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });

        // Estimate fees
        MessagingFee memory fee = IOFT(address(gains)).quoteSend(sendParam, false);
        console.log("Estimated Native Fee: %s", fee.nativeFee);

        // Send tokens
        IOFT(address(gains)).send{ value: fee.nativeFee }(
            sendParam,
            fee,
            deployerAddress // refund address
        );

        vm.stopBroadcast();
    }

    /**
     * @notice Example run function:
     *    1) sets peers on both chains,
     *    2) sends 1 GAINS cross-chain.
     */
    function run() public {
        // Get private key and verify owner
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address currentOwner = GAINS(GAINS_ETH_SEPOLIA).owner();
        require(deployerAddress == currentOwner, "Must be called by the owner");

        uint256 balance = gains.balanceOf(deployerAddress);

        require(balance >= 1e18, "Not enough GAINS to bridge");

        // 1) Set peers so each chain trusts the other
        setPeers();

        // 2) Bridge 1 GAINS
        bridgeTokens(1e18, deployerAddress);
    }
}
