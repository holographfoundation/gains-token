// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/HolographERC20Interface.sol";
import "./GAINS.sol";

/**
 * @title MigrateToGAINS
 * @notice Burns HLG from a user, then mints GAINS (OFT) to the same user 1:1.
 */
contract MigrateToGAINS {
    HolographERC20Interface public immutable hlg;
    GAINS public immutable gains;

    event Migrated(address indexed user, uint256 amount);

    /**
     * @param _hlg Address of the deployed HLG (HolographUtilityToken) contract proxy.
     * @param _gains Address of the deployed GAINS (OFT) contract.
     */
    constructor(address _hlg, address _gains) {
        hlg = HolographERC20Interface(_hlg);
        gains = GAINS(_gains);
    }

    /**
     * @notice Migrate the caller's HLG into GAINS 1:1.
     * @dev The caller must first approve this contract on HLG for `amount`.
     * @param amount The amount of HLG to burn and convert.
     */
    function migrate(uint256 amount) external {
        // Burn HLG from the caller's wallet (requires user approval).
        hlg.sourceBurn(msg.sender, amount);

        // Mint GAINS 1:1 to the caller.
        gains.mintForMigration(msg.sender, amount);

        emit Migrated(msg.sender, amount);
    }
}
