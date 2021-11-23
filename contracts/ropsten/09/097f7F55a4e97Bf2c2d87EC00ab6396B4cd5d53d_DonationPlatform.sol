// SPDX-License-Identifier: MIT  
pragma solidity ^0.8.0;
/// @title DonationPlatform 
/// @author Aleks
/// @dev Bug when returning funds, figured out events and minting
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SimpleNft.sol";

contract DonationPlatform is Ownable {
    /// @notice Create campaigns and recieve funds
    
    /// @notice Campaign struct with propperties
    struct Campaign {
        string name;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 raised;
        bool isComplete;
    }
    
    
    address private nftaddress;                 // address containing nft token's address
    uint256 public campaignCount = 0;           // campaign count & campaign ID
    mapping (uint => Campaign) public campaigns; 
    mapping (address => bool) public hasDonatedBefore; 

    event CampaignCreated(uint CampaignId, Campaign campaign_info );
    event DonationSent(uint campaignId, uint value, address sender);


    function changeNftAddress(address _nftaddress) public onlyOwner {
        nftaddress = _nftaddress;
    }
    
        
    
    
    /// @notice creates donation campaign with properties
    /// @param _name, _description, _goal, _deadline raised and complete set to default
    function addCampaign(
        string memory _name, string memory _description,
        uint _goal, uint _deadline
        )
        public onlyOwner {
        campaignCount +=1;
        campaigns[campaignCount] = Campaign(_name, _description, _goal, _deadline + block.timestamp, 0, false );
        emit CampaignCreated(campaignCount, campaigns[campaignCount]);
    }
    
    
    
    /// @notice donation function , adds msg.value to raised amount of corresponding campaign 
    /// @param id Id of campaign
    /// @dev It doesnt return the change funds via call.
    function donate(uint id) payable public {
        require(block.timestamp < campaigns[id].deadline, "Campaign is over!");
        require(!(campaigns[id].isComplete), "The goal was already achieved!");
        if (!hasDonatedBefore[msg.sender]){
            hasDonatedBefore[msg.sender]= true;
            SimpleNft(nftaddress).mint(msg.sender);             /// mints the nft to the sender's address
            
        }

        campaigns[id].raised += msg.value;

        if (campaigns[id].raised + msg.value > campaigns[id].goal) {
            uint _amount = campaigns[id].raised - campaigns[id].goal;
            campaigns[id].raised -= _amount;
            campaigns[id].isComplete = true;
            (bool success, ) = msg.sender.call{value:_amount}("");
            require(success, "Transfer failed.");
        } else if (campaigns[id].raised == campaigns[id].goal) campaigns[id].isComplete = true;
        emit DonationSent(id, msg.value, msg.sender );
    }
}