// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { GAINS } from "../GAINS.sol";

// @dev WARNING: This is for testing purposes only
contract GAINSMock is GAINS {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) GAINS(_name, _symbol, _lzEndpoint, _delegate) {}

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
