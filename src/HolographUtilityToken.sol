// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import "../abstract/HLGERC20H.sol";

import "../interface/ERC20.sol";
import "../interface/HolographERC20Interface.sol";
import "../interface/HolographInterface.sol";
import "../interface/HolographerInterface.sol";

/**
 * @title Holograph Utility Token.
 * @author Holograph Foundation
 * @notice A smart contract for minting and managing Holograph's ERC20 Utility Tokens.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
contract HolographUtilityToken is HLGERC20H {
    /**
     * @dev Constructor is left empty and init is used instead
     */
    constructor() {}

    /**
     * @notice Used internally to initialize the contract instead of through a constructor
     * @dev This function is called by the deployer/factory when creating a contract
     * @param initPayload abi encoded payload to use for contract initilaization
     */
    function init(bytes memory initPayload) external override returns (bytes4) {
        (address contractOwner, uint256 tokenAmount, uint256 targetChain, address tokenRecipient) = abi.decode(
            initPayload,
            (address, uint256, uint256, address)
        );
        _setOwner(contractOwner);
        /*
         * @dev Mint token only if target chain matches current chain. Or if no target chain has been selected.
         *      Goal of this is to restrict minting on Ethereum only for mainnet deployment.
         */
        if (block.chainid == targetChain || targetChain == 0) {
            if (tokenAmount > 0) {
                HolographERC20Interface(msg.sender).sourceMint(tokenRecipient, tokenAmount);
            }
        }
        // run underlying initializer logic
        return _init(initPayload);
    }

    /**
     * @dev Temporarily placed to bypass bytecode conflicts
     */
    function isHLG() external pure returns (bool) {
        return true;
    }
}
