// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./interfaces/HolographERC20Interface.sol";
import "./GAINS.sol";

/**
 * @title MigrateHLGToGAINS
 * @notice Burns HLG from a user, then mints GAINS (OFT) to the same user 1:1.
 */
contract MigrateHLGToGAINS {
    error ZeroAddressInConstructor();
    error ZeroAmount();
    error BurnFromFailed();

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
     * @param _hlg Address of the deployed HLG (HolographUtilityToken) contract proxy.
     * @param _gains Address of the deployed GAINS (OFT) contract.
     */
    constructor(address _hlg, address _gains) {
        if (_hlg == address(0) || _gains == address(0)) {
            revert ZeroAddressInConstructor();
        }
        hlg = HolographERC20Interface(_hlg);
        gains = GAINS(_gains);
    }

    /**
     * @notice Migrate the caller's HLG into GAINS 1:1.
     * @dev The caller must first approve this contract on HLG for `amount`.
     * @param amount The amount of HLG to burn and convert.
     */
    function migrate(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        // @notice The user must have approved the HLG contract before calling.
        if (!hlg.burnFrom(msg.sender, amount)) {
            revert BurnFromFailed();
        }

        // Mint GAINS 1:1 to the caller
        gains.mintForMigration(msg.sender, amount);

        emit MigratedHLGToGAINS(msg.sender, amount);
    }
}
