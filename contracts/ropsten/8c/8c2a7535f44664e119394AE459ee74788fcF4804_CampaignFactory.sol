// SPDX-License-Identifier: MIT

pragma solidity 0.4.22;

import './Compaign.sol';


contract CampaignFactory {
    Compaign[] public deployedCampaigns;

    function createCampaign(string memory campaigntitle) public {
        Compaign newCampaign = new Compaign(campaigntitle,msg.sender);
        deployedCampaigns.push(newCampaign);
    }

    function getDeployedCampaigns() public view returns (Compaign[] memory) {
        return deployedCampaigns;
    }
}