// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface ERC20Burnable {
    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external returns (bool);
}
