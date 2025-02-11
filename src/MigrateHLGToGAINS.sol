// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/HolographERC20Interface.sol";
import "./GAINS.sol";

/**
 * @title MigrateHLGToGAINS
 * @notice Burns HLG from a user, then mints GAINS (OFT) to the same user 1:1.
 * @dev Includes pause functionality to disable migration if needed.
 */
contract MigrateHLGToGAINS is Pausable, Ownable {
    error ZeroAddressInConstructor();
    error ZeroAmount();
    error BurnFromFailed();
    error NotOnAllowlist();
    error ZeroAddressProvided();

    /**
     * @notice Interface for the HLG token being migrated (must support burnFrom).
     */
    HolographERC20Interface public immutable hlg;

    /**
     * @notice GAINS (OFT) contract, which is minted into at a 1:1 ratio.
     */
    GAINS public immutable gains;

    /**
     * @notice Emitted when a user migrates HLG -> GAINS.
     * @param user The user who did the migration.
     * @param amount The amount of HLG burned & GAINS minted.
     */
    event MigratedHLGToGAINS(address indexed user, uint256 amount);

    /**
     * @notice Emitted when an account is added to the allowlist.
     */
    event AddedToAllowlist(address indexed account);

    /**
     * @notice Emitted when an account is removed from the allowlist.
     */
    event RemovedFromAllowlist(address indexed account);

    /**
     * @notice Emitted when the allowlist is deactivated.
     */
    event AllowlistDeactivated();

    /// @notice When active, only addresses in the allowlist may migrate.
    bool public allowlistActive;

    /// @notice Mapping of allowed addresses.
    mapping(address => bool) public allowlist;

    /**
     * @param _hlg Address of the deployed HLG (HolographUtilityToken) contract proxy.
     * @param _gains Address of the deployed GAINS (OFT) contract.
     * @param _owner The address that should be set as the owner.
     *
     * @dev Pass _owner explicitly so that the intended deployer (not the create2 factory)
     *      becomes the owner. This fixes the issue where msg.sender (i.e. the factory)
     *      was incorrectly assigned as owner.
     */
    constructor(address _hlg, address _gains, address _owner) Ownable(_owner) {
        if (_hlg == address(0) || _gains == address(0)) {
            revert ZeroAddressInConstructor();
        }
        hlg = HolographERC20Interface(_hlg);
        gains = GAINS(_gains);

        // By default, the allowlist is active.
        // This will be turned off when the migration is open to the public.
        allowlistActive = true;
    }

    /**
     * @notice Pauses the migration functionality.
     * @dev Only callable by the owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the migration functionality.
     * @dev Only callable by the owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Adds a single account to the allowlist.
     * @param account The account to add.
     */
    function addToAllowlist(address account) external onlyOwner {
        if (account == address(0)) revert ZeroAddressProvided();
        allowlist[account] = true;
        emit AddedToAllowlist(account);
    }

    /**
     * @notice Removes an account from the allowlist.
     * @param account The account to remove.
     */
    function removeFromAllowlist(address account) external onlyOwner {
        allowlist[account] = false;
        emit RemovedFromAllowlist(account);
    }

    /**
     * @notice Deactivates the entire allowlist.
     */
    function deactivateAllowlist() external onlyOwner {
        allowlistActive = false;
        emit AllowlistDeactivated();
    }

    /**
     * @notice Batch-adds multiple accounts to the allowlist.
     * @param accounts The array of accounts to add.
     */
    function batchAddToAllowlist(address[] calldata accounts) external onlyOwner {
        uint256 len = accounts.length;
        for (uint256 i; i < len; ++i) {
            if (accounts[i] == address(0)) revert ZeroAddressProvided();
            allowlist[accounts[i]] = true;
            emit AddedToAllowlist(accounts[i]);
        }
    }

    /**
     * @notice Migrate the caller's HLG into GAINS 1:1.
     * @dev The caller must first approve this contract on HLG for `amount`.
     *      Function is disabled when paused.
     * @param amount The amount of HLG to burn and convert.
     */
    function migrate(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (allowlistActive && !allowlist[msg.sender]) revert NotOnAllowlist();

        // The user must have approved the HLG contract before calling.
        if (!hlg.burnFrom(msg.sender, amount)) revert BurnFromFailed();

        // Mint GAINS 1:1 to the caller.
        gains.mintForMigration(msg.sender, amount);

        emit MigratedHLGToGAINS(msg.sender, amount);
    }
}
