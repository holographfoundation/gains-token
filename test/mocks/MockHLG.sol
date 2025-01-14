// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/HolographERC20Interface.sol";
import "../../src/interfaces/ERC20Receiver.sol";
/**
 * @dev Minimal mock replicating key HolographERC20 logic:
 *      1) Balances
 *      2) Approvals
 *      3) sourceBurn(msg.sender, amount) which reverts if allowance/balance is insufficient
 *      4) Revert messages match the real contract:
 *         - “ERC20: amount exceeds allowance”
 *         - “ERC20: amount exceeds balance”
 */
contract MockHLG is HolographERC20Interface {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    mapping(address => uint256) internal _balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowance;
    mapping(address => uint256) private _nonces;
    uint256 internal _totalSupply;

    // ERC-2612 typehash
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // --------------------------------------------------
    // ERC20-like basics
    // --------------------------------------------------
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return _balanceOf[_owner];
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert("Not needed in this mock");
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert("Not needed in this mock");
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowance[msg.sender][spender] = amount;
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowance[owner][spender];
    }

    // --------------------------------------------------
    // Testing "Mint" to seed balances
    // --------------------------------------------------
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        _balanceOf[to] += amount;
        _totalSupply += amount;
    }

    // --------------------------------------------------
    // The main calls GainsMigration does
    // --------------------------------------------------

    /**
     * @notice Mirror real HolographERC20 “sourceBurn(address from, uint256 amount)”
     *         Also replicate the real revert messages for allowance & balance checks.
     */
    function sourceBurn(address from, uint256 amount) external {
        // 1) Check allowance
        uint256 allowed = _allowance[from][msg.sender];
        require(allowed >= amount, "ERC20: amount exceeds allowance");

        // 2) Check balance
        uint256 balance = _balanceOf[from];
        require(balance >= amount, "ERC20: amount exceeds balance");

        // Burn
        _balanceOf[from] = balance - amount;
        unchecked {
            _totalSupply -= amount;
        }
    }

    function sourceMint(address to, uint256 amount) external {
        _mint(to, amount); // Reuse existing mint functionality
    }

    function sourceMintBatch(address[] calldata tos, uint256[] calldata amounts) external {
        require(tos.length == amounts.length, "Length mismatch");
        for(uint i = 0; i < tos.length; i++) {
            _mint(tos[i], amounts[i]);
        }
    }

    function sourceTransfer(address from, address to, uint256 amount) external {
        require(_balanceOf[from] >= amount, "ERC20: amount exceeds balance");
        _balanceOf[from] -= amount;
        _balanceOf[to] += amount;
    }

    function sourceTransfer(address payable to, uint256 amount) external {
        bool success = to.send(amount);
        require(success, "Transfer failed");
    }

    function sourceExternalCall(address target, bytes calldata data) external {
        // Basic target contract call
        (bool success, ) = target.call(data);
        require(success, "External call failed");
    }

    // --------------------------------------------------
    // Additional HolographERC20Interface stubs
    // --------------------------------------------------

    function holographBridgeMint(address to, uint256 amount) external returns (bytes4) {
        _mint(to, amount);
        return this.holographBridgeMint.selector;
    }

    // EIP-2612 and domain
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return keccak256("MockHLG"); // Simplified for mock
    }

    function nonces(address account) external view returns (uint256) {
        return _nonces[account];
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "Permit expired");
        _nonces[owner]++;
        _allowance[owner][spender] = value;
    }

    // ERC20 Safer functions
    function _safeTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(_balanceOf[sender] >= amount, "ERC20: amount exceeds balance");
        _balanceOf[sender] -= amount;
        _balanceOf[recipient] += amount;
        return true;
    }

    function safeTransfer(address recipient, uint256 amount) external returns (bool) {
        return _safeTransfer(msg.sender, recipient, amount);
    }

    function safeTransfer(address recipient, uint256 amount, bytes memory data) external returns (bool) {
        _safeTransfer(msg.sender, recipient, amount);
        if (recipient.code.length > 0) {
            require(
                ERC20Receiver(recipient).onERC20Received(msg.sender, msg.sender, amount, data) ==
                    ERC20Receiver.onERC20Received.selector,
                "ERC20: transfer rejected"
            );
        }
        return true;
    }

    function _safeTransferFrom(
        address sender,
        address account,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(_allowance[account][sender] >= amount, "ERC20: amount exceeds allowance");
        _allowance[account][sender] -= amount;
        _balanceOf[account] -= amount;
        _balanceOf[recipient] += amount;
        return true;
    }

    function safeTransferFrom(address account, address recipient, uint256 amount) external returns (bool) {
        return _safeTransferFrom(msg.sender, account, recipient, amount);
    }

    function safeTransferFrom(
        address account,
        address recipient,
        uint256 amount,
        bytes memory data
    ) external returns (bool) {
        _safeTransferFrom(msg.sender, account, recipient, amount);
        if (recipient.code.length > 0) {
            require(
                ERC20Receiver(recipient).onERC20Received(msg.sender, account, amount, data) ==
                    ERC20Receiver.onERC20Received.selector,
                "ERC20: transfer rejected"
            );
        }
        return true;
    }

    // ERC20 Burnable functions
    function burn(uint256 amount) external {
        require(_balanceOf[msg.sender] >= amount, "ERC20: amount exceeds balance");
        _balanceOf[msg.sender] -= amount;
        _totalSupply -= amount;
    }

    function burnFrom(address account, uint256 amount) external returns (bool) {
        require(_allowance[account][msg.sender] >= amount, "ERC20: amount exceeds allowance");
        require(_balanceOf[account] >= amount, "ERC20: amount exceeds balance");
        _allowance[account][msg.sender] -= amount;
        _balanceOf[account] -= amount;
        _totalSupply -= amount;
        return true;
    }

    // Bridge functions
    function bridgeIn(uint32 fromChain, bytes calldata payload) external returns (bytes4) {
        // Basic mock that accepts all bridge-ins
        return this.bridgeIn.selector;
    }

    function bridgeOut(
        uint32 toChain,
        address sender,
        bytes calldata payload
    ) external returns (bytes4 selector, bytes memory data) {
        // Basic mock that accepts all bridge-outs
        return (this.bridgeOut.selector, payload);
    }

    // ERC20 Receiver
    function onERC20Received(
        address operator,
        address from,
        uint256 amount,
        bytes memory data
    ) external returns (bytes4) {
        return this.onERC20Received.selector;
    }

    // ERC165
    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return interfaceID == type(HolographERC20Interface).interfaceId;
    }
}
