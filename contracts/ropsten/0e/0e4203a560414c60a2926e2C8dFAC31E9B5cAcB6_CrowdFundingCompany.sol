// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

/******************************************************************************\
* Author: Battambang
* CrowdFundingCompany contract to instantiate Campaign contracts
/******************************************************************************/

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./Campaign.sol";

contract CrowdFundingCompany is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    address[] public deployedCampaigns;
    address public minimalForwarder;
    string public companyName;

    event CampaignDeployed(address campaign);

    /**
     * @dev Initializes the contract.
     * @param currentCompanyName company name.
     */
    function initialize(string memory currentCompanyName) public initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __Pausable_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        companyName = currentCompanyName;
    }

    /**
     * @dev pauses the contract.
     * Only the contract admin can call.
     */
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev unpauses the contract.
     * Only the contract admin can call.
     */
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev creates campaign contracts.
     * @param minimumContrib minimum fund to contribute.
     * @param fundingGoal expected funding.
     * @param timeLength duration in unix timestamp.
     */
    function createTrustedCampaign(
        uint256 minimumContrib,
        uint256 fundingGoal,
        uint256 timeLength
    ) public whenNotPaused {
        address newTrustedCampaign = address(
            new Campaign(
                minimumContrib,
                fundingGoal,
                timeLength,
                msg.sender,
                minimalForwarder
            )
        );
        deployedCampaigns.push(newTrustedCampaign);
        emit CampaignDeployed(newTrustedCampaign);
    }

    /**
     * @dev gets a deployed campaign.
     * @param index index of the campaign.
     */
    function getCampaign(uint256 index) public view returns (address campaign) {
        return deployedCampaigns[index];
    }

    /**
     * @dev gets total number of deployed campaigns.
     */
    function getTotalCampaigns() public view returns (uint256) {
        return deployedCampaigns.length;
    }

    /**
     * @dev sets minimalForwarder.
     * @param forwarder forwarder address.
     * Only the contract admin can call.
     */
    function setMinimalForwarder(address forwarder)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        minimalForwarder = forwarder;
    }
}