// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../src/GAINS.sol";

// For bridging calls (quoteSend, send)
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

// For setPeer (whitelisting) checks
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * @title BridgeGAINSScript
 * @notice Script to bridge GAINS tokens between two LayerZero chains.
 * Run with:
 * forge script script/BridgeGAINS.s.sol:BridgeGAINSScript --rpc-url <rpc-url> --broadcast -vvvv
 */
contract BridgeGAINSScript is Script {
    using OptionsBuilder for bytes; // For addExecutorLzReceiveOption()

    GAINS public gains;

    uint32 constant ETH_SEPOLIA_CHAIN_ID = 40161;
    uint32 constant BASE_SEPOLIA_CHAIN_ID = 40245;
    address constant GAINS_ETH_SEPOLIA = 0x27ab1eF46295406d2190f7DbC4cDCFe6590CE076;
    address constant GAINS_BASE_SEPOLIA = 0x27ab1eF46295406d2190f7DbC4cDCFe6590CE076;

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
     * @notice Checks if peers are already set between the chains.
     * @dev Throws an error if peers are not set.
     */
    function checkPeers() internal view {
        // Check if ETH Sepolia -> Base Sepolia peer is set
        bytes32 baseSepoliaPeer = IOAppCore(GAINS_ETH_SEPOLIA).peers(BASE_SEPOLIA_CHAIN_ID);
        require(
            baseSepoliaPeer == addressToBytes32(GAINS_BASE_SEPOLIA),
            "Peer for Base Sepolia is not set. Run SetPeers script first."
        );

        // Check if Base Sepolia -> ETH Sepolia peer is set
        bytes32 ethSepoliaPeer = IOAppCore(GAINS_BASE_SEPOLIA).peers(ETH_SEPOLIA_CHAIN_ID);
        require(
            ethSepoliaPeer == addressToBytes32(GAINS_ETH_SEPOLIA),
            "Peer for ETH Sepolia is not set. Run SetPeers script first."
        );

        console.log("Peers are set between ETH Sepolia and Base Sepolia.");
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

        // Check if peers are set
        checkPeers();

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
        IOFT(address(gains)).send{value: fee.nativeFee}(
            sendParam,
            fee,
            deployerAddress // refund address
        );

        vm.stopBroadcast();
    }

    /**
     * @notice Run function bridges 1 GAINS cross-chain.
     */
    function run() public {
        // Get private key and verify owner
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address currentOwner = GAINS(GAINS_ETH_SEPOLIA).owner();
        require(deployerAddress == currentOwner, "Must be called by the owner");

        uint256 balance = gains.balanceOf(deployerAddress);

        require(balance >= 1e18, "Not enough GAINS to bridge");

        // Bridge 1 GAINS
        bridgeTokens(1e18, deployerAddress);
    }
}
