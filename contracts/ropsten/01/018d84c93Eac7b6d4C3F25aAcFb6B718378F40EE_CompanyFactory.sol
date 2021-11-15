// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

/******************************************************************************\
* Author: Battambang
* CompanyFactory class
/******************************************************************************/

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../contracts/Campaign.sol";

contract CompanyFactory is Initializable, OwnableUpgradeable {
    address[] public deployedCampaigns;
    string public companyName;

    function initialize(string memory currentCompanyName) public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        companyName = currentCompanyName;
    }

    function createTrustedCampaign(uint256 minimum) public {
        address newTrustedCampaign = address(new Campaign(minimum, msg.sender));
        deployedCampaigns.push(newTrustedCampaign);
    }

    function getDeployedCampaigns() public view returns (address[] memory) {
        return deployedCampaigns;
    }
}