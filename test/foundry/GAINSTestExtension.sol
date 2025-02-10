// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../src/GAINS.sol";

/**
 * @title GAINSTest
 * @notice A test-only version of GAINS that adds a `testMint` function for local Foundry tests.
 */
contract GAINSTestExtension is GAINS {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) GAINS(_name, _symbol, _lzEndpoint, _delegate) {}

    /**
     * @notice Mint tokens to a specified address (testing only).
     * @dev Only callable by contract owner in local tests.
     * @param _to Address to receive the minted tokens
     * @param _amount Amount of tokens to mint
     */
    function testMint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}
