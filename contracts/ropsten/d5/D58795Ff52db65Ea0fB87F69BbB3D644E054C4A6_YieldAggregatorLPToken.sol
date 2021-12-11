pragma solidity ^0.8.0;
// Copyright 2021 Keyko GmbH.
// SPDX-License-Identifier: (CC-BY-NC-ND-3.0)
// Code and docs are CC-BY-NC-ND-3.0

import "./UsdcTokenInterface.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @title YieldAggregatorLP Token Mock implementation
 * @author Keyko
 *
 * @dev Contract that implements a ERC20 token which will be
 *      used as a mock for YieldAggregatorLP token
 *
 */

contract YieldAggregatorLPToken is
    IUsdcToken,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    bytes32 public constant MINTER_AND_BURNER_ROLE =
        keccak256("MINTER_AND_BURNER_ROLE");

    /**
     * @notice initialize init the contract with the following parameters
     * @dev this function is called only once during the contract initialization
     */
    function initialize() external initializer {
        ERC20Upgradeable.__ERC20_init("YieldAggregatorLP Token", "YAL");
        OwnableUpgradeable.__Ownable_init();
        AccessControlUpgradeable.__AccessControl_init();
        AccessControlUpgradeable._setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev Creates 'amount' of tokens and assigns them to 'account' balance, increasing
     * the total supply.
     * @param _account account for which the 'amount' of tokens will be created
     * @param _amount amount of tokens that will be created
     */
    function mint(address _account, uint256 _amount) public override {
        require(
            hasRole(MINTER_AND_BURNER_ROLE, _msgSender()),
            "YieldAggregatorLP: You don't have permission to mint tokens!"
        );
        super._mint(_account, _amount);
        emit Mint(_account, _amount);
    }

    /**
     * @dev Removes 'amount' of tokens from the 'account' balance, decreasing
     * the total supply.
     * @param _account account from which the 'amount' of tokens is removed
     * @param _amount amount of tokens that will be removed
     */
    function burn(address _account, uint256 _amount) public override {
        require(
            hasRole(MINTER_AND_BURNER_ROLE, _msgSender()),
            "YieldAggregatorLP: You don't have permission to burn tokens!"
        );
        super._burn(_account, _amount);
        emit Burn(_account, _amount);
    }

    /**
     * @notice used to grant an address the rights to mint and burn
     * Rand internal token
     * @param _address new address of the Vault contract
     */
    function grantMintAndBurnRights(address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _address != address(0),
            "YieldAggregatorLP: contract address cannot be address 0!"
        );
        AccessControlUpgradeable.grantRole(MINTER_AND_BURNER_ROLE, _address);
    }
}