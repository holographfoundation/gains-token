// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./ERC20.sol" /* IERC20Custom */;
import "./ERC20Burnable.sol";
import "./ERC20Metadata.sol";
import "./ERC20Permit.sol";
import "./ERC20Receiver.sol";
import "./ERC20Safer.sol";
import "./ERC165.sol";
import "./Holographable.sol";

interface HolographERC20Interface is
    ERC165,
    IERC20Custom,
    ERC20Burnable,
    ERC20Metadata,
    ERC20Receiver,
    ERC20Safer,
    ERC20Permit,
    Holographable
{
    function holographBridgeMint(address to, uint256 amount) external returns (bytes4);

    function sourceBurn(address from, uint256 amount) external;

    function sourceMint(address to, uint256 amount) external;

    function sourceMintBatch(address[] calldata wallets, uint256[] calldata amounts) external;

    function sourceTransfer(address from, address to, uint256 amount) external;

    function sourceTransfer(address payable destination, uint256 amount) external;

    function sourceExternalCall(address target, bytes calldata data) external;
}
