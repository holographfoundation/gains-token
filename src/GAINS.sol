// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/oft-evm/contracts/OFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GAINS token - an Omnichain Fungible Token (simple).
 * @notice Inherits the base OFT from the LayerZero EVM library.
 */
contract GAINS is OFT {
    /**
     * @dev The GainsMigration contract that will do the minting for HLG->GAINS migration.
     */
    address public migrationContract;

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) Ownable(msg.sender) OFT(_name, _symbol, _lzEndpoint, _delegate) {}

    /**
     * @notice Assign or update the GainsMigration contract allowed to mint new tokens.
     * @dev Only the owner can set or update this.
     */
    function setMigrationContract(address _migrationContract) external onlyOwner {
        migrationContract = _migrationContract;
    }

    modifier onlyMigrationContract() {
        require(msg.sender == migrationContract, "GAINS: not migration contract");
        _;
    }

    /**
     * @notice Mint tokens for local chain migration from HLG.
     * @dev Only callable by the GainsMigration contract.
     * @param _to Recipient of newly minted tokens.
     * @param _amount Amount of tokens to mint.
     */
    function mintForMigration(address _to, uint256 _amount) external onlyMigrationContract {
        _mint(_to, _amount);
    }

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
