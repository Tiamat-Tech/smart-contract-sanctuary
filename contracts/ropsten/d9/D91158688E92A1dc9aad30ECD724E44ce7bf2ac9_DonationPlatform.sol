// SPDX-License-Identifier: MIT  
pragma solidity ^0.8.0;
/// @title DonationPlatform 
/// @author Aleks
/// @dev So far didnt spot any errors
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SimpleNft.sol";

contract DonationPlatform is Ownable {
    
   
    
    
    // creating campaign attributes
    struct Campaign {
        uint256 id;
        string name;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 raised;
        bool isComplete;
    }
    
    // address containing nft tokekn's address
    address nftaddress;
    uint256 campaignCount = 0;
    mapping (uint => Campaign) public campaigns;
    mapping (address => bool) public hasDonatedBefore;


    function changeNftAddress(address _nftaddress) public onlyOwner {
        nftaddress = _nftaddress;
    }
    
        
    
    
    function addCampaign(
        string memory name, string memory description,
        uint goal, uint deadline
        )
        public onlyOwner {
        uint raised = 0;
        bool isComplete = false;
        campaignCount +=1;
        campaigns[campaignCount] = Campaign(campaignCount, name, description, goal,deadline + block.timestamp, raised, isComplete);
    }
    
    
    
    function donate(uint id) payable public {
        require(block.timestamp < campaigns[id].deadline, "Campaign is over!");
        require(!(campaigns[id].isComplete), "The goal was already achieved!");
        if (!hasDonatedBefore[msg.sender]){
            hasDonatedBefore[msg.sender]= true;
            SimpleNft (nftaddress).mint(msg.sender);
            
        }
        

        campaigns[id].raised += msg.value;
        
        

        if (campaigns[id].raised + msg.value > campaigns[id].goal) {
            uint _amount = campaigns[id].raised - campaigns[id].goal;
            campaigns[id].raised -= _amount;
            campaigns[id].isComplete = true;
            (bool success, ) = msg.sender.call{value:_amount}("");
        require(success, "Transfer failed.");
        } else if (campaigns[id].raised == campaigns[id].goal) campaigns[id].isComplete = true;
    }
}