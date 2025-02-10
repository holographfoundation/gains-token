// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

interface Holographable {
    function bridgeIn(uint32 fromChain, bytes calldata payload) external returns (bytes4);

    function bridgeOut(
        uint32 toChain,
        address sender,
        bytes calldata payload
    ) external returns (bytes4 selector, bytes memory data);
}
