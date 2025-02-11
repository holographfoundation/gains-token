// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/GAINS.sol";

contract TransferOwnership is Script {
    function run() external {
        address GAINS_CONTRACT = vm.envAddress("GAINS_CONTRACT");
        address GNOSIS_SAFE = vm.envAddress("GNOSIS_SAFE");

        vm.startBroadcast();

        GAINS gains = GAINS(GAINS_CONTRACT);
        gains.transferOwnership(GNOSIS_SAFE);

        vm.stopBroadcast();

        console.log("Ownership transferred to Gnosis Safe:", GNOSIS_SAFE);
    }
}
