// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/interfaces/HolographERC20Interface.sol";

/**
 * @title MockHLG
 * @notice A minimal mock to stand in for the real HolographUtilityToken in testing.
 */
contract MockHLG is HolographERC20Interface, Test {
    string private _name;
    string private _symbol;
    uint8 private _decimals = 18;

    mapping(address => uint256) internal _balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowance;

    uint256 internal _totalSupply;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    // ============ ERC20 Base Logic ============

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return _balanceOf[_owner];
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        revert("Not used in mock");
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        revert("Not used in mock");
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        _allowance[msg.sender][_spender] = _value;
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return _allowance[_owner][_spender];
    }

    // ============ ERC20Permit ============

    function permit(
        address account,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        revert("Not implemented in mock");
    }

    function nonces(address account) external view returns (uint256) {
        revert("Not implemented in mock");
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        revert("Not implemented in mock");
    }

    // ============ Holographable ============

    function bridgeIn(uint32 fromChain, bytes calldata payload) external returns (bytes4) {
        return this.bridgeIn.selector;
    }

    function bridgeOut(
        uint32 toChain,
        address sender,
        bytes calldata payload
    ) external returns (bytes4 selector, bytes memory data) {
        revert("Not used in mock");
    }

    // ============ ERC20Burnable ============

    function burn(uint256 amount) external {
        revert("Not used in mock");
    }

    function burnFrom(address account, uint256 amount) external returns (bool) {
        revert("Not used in mock");
    }

    // ============ ERC20Receiver ============

    function onERC20Received(
        address account,
        address recipient,
        uint256 amount,
        bytes memory data
    ) external returns (bytes4) {
        revert("Not used in mock");
    }

    // ============ ERC20Safer ============

    function safeTransfer(address recipient, uint256 amount) external returns (bool) {
        revert("Not used in mock");
    }

    function safeTransfer(address recipient, uint256 amount, bytes memory data) external returns (bool) {
        revert("Not used in mock");
    }

    function safeTransferFrom(address account, address recipient, uint256 amount) external returns (bool) {
        revert("Not used in mock");
    }

    function safeTransferFrom(
        address account,
        address recipient,
        uint256 amount,
        bytes memory data
    ) external returns (bool) {
        revert("Not used in mock");
    }

    // ============ ERC165 ============

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return false;
    }

    // ============ Additional Functions ============

    /**
     * @notice "Mint" some HLG for testing
     */
    function mint(address to, uint256 amount) external {
        _balanceOf[to] += amount;
        _totalSupply += amount;
    }

    // ============ HolographERC20Interface ============

    // we don’t implement bridging logic here. This is for local chain test only.

    function holographBridgeMint(address, uint256) external returns (bytes4) {
        revert("Not used in this mock");
    }

    function sourceBurn(address from, uint256 amount) external {
        // Check allowance
        require(_allowance[from][msg.sender] >= amount, "ERC20: insufficient allowance");
        // Check balance
        require(_balanceOf[from] >= amount, "HLG: insufficient balance");

        // "burn"
        _balanceOf[from] -= amount;
        _totalSupply -= amount;
    }

    function sourceMint(address, uint256) external {
        revert("Not used in this mock");
    }

    function sourceMintBatch(address[] calldata, uint256[] calldata) external {
        revert("Not used in this mock");
    }

    function sourceTransfer(address, address, uint256) external {
        revert("Not used in this mock");
    }

    function sourceTransfer(address payable, uint256) external {
        revert("Not used in this mock");
    }

    function sourceExternalCall(address, bytes calldata) external {
        revert("Not used in this mock");
    }

    // ============ ERC20Metadata ============

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}
