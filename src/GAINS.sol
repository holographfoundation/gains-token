// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@layerzerolabs/oft-evm/contracts/OFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GAINS token - an Omnichain Fungible Token.
 * @notice Inherits the base OFT from the LayerZero EVM library for cross-chain compatibility.
 */
contract GAINS is OFT {
    error NotMigrationContract();
    error ZeroAddress();
    error MigrationContractAlreadySet();

    /**
     * @dev The MigrateHLGToGAINS contract that will do the minting for HLG->GAINS migration.
     */
    address public migrationContract;

    /**
     * @dev Emitted when the `migrationContract` address is set.
     */
    event MigrationContractSet(address indexed migrationContract);

    /**
     * @param _name ERC20 name (e.g., "GAINS")
     * @param _symbol ERC20 symbol (e.g., "GAINS")
     * @param _lzEndpoint The LayerZero endpoint address
     * @param _delegate The address to set as contract owner (Ownable)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) Ownable(_delegate) OFT(_name, _symbol, _lzEndpoint, _delegate) {
        if (_lzEndpoint == address(0)) revert ZeroAddress();
        if (_delegate == address(0)) revert ZeroAddress();
    }

    /**
     * @notice Sets the MigrateHLGToGAINS contract allowed to mint new tokens.
     *         This can be called only once to lock out any subsequent changes.
     * @dev Only the owner can call this. Reverts if already set.
     * @param _migrationContract The address of the migration contract.
     */
    function setMigrationContract(address _migrationContract) external onlyOwner {
        if (migrationContract != address(0)) revert MigrationContractAlreadySet();
        if (_migrationContract == address(0)) revert ZeroAddress();

        migrationContract = _migrationContract;

        emit MigrationContractSet(_migrationContract);
    }

    /**
     * @dev Restricts function access to only the `migrationContract`.
     */
    modifier onlyMigrationContract() {
        if (msg.sender != migrationContract) revert NotMigrationContract();
        _;
    }

    /**
     * @notice Mint tokens for local chain migration from HLG.
     * @dev Only callable by the MigrateHLGToGAINS contract.
     * @param _to Recipient of newly minted tokens.
     * @param _amount Amount of tokens to mint.
     */
    function mintForMigration(address _to, uint256 _amount) external onlyMigrationContract {
        _mint(_to, _amount);
    }
}
