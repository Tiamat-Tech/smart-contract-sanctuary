pragma solidity ^0.8.0;
//SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";


contract CampaignManager is AccessControl {

    enum Status { Created, Started, Upload, Voting, Ended }
    struct Campaign {
        Status status;
        bytes32 name;
        bytes32 artistName;
        address artistAddress;
        bytes32 imageURL;
        uint8 numNFTs;
        uint rewardPerBlock;
    }

    struct StatusCheckpoint {
        uint Block;
        uint Timestamp;
    }
    mapping(uint => mapping (uint8 => StatusCheckpoint)) campaignStatusCheckpoint;

    uint numCampaigns;
    Campaign[] public campaigns;
    bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");


    constructor(address _campaign_admin) {
        _setupRole(CAMPAIGN_ADMIN_ROLE, _campaign_admin);
        _setupRole(DEFAULT_ADMIN_ROLE, _campaign_admin);
    }


    modifier checkRole(
        bytes32 role,
        address account,
        string memory message
    ) {
        require(hasRole(role, account), message);
        _;
    }

    function addCampaignAdmin(address _campaign_admin)
        external
        checkRole(CAMPAIGN_ADMIN_ROLE, msg.sender, "Caller is not campaign admin")
    {
        grantRole(CAMPAIGN_ADMIN_ROLE,_campaign_admin);
    }

    function removeCampaignAdmin(address _campaign_admin)
        external
        checkRole(CAMPAIGN_ADMIN_ROLE, msg.sender, "Caller is not campaign admin")
    {
        revokeRole(CAMPAIGN_ADMIN_ROLE,_campaign_admin);
    }

     function getCampaignByIndex(uint _index) public view returns (Campaign memory) {
         return campaigns[_index];
     }


     function getCampaignPrevStatusByIndex(uint _index) public view returns (uint, uint) {
         require(campaigns[_index].status > Status.Created, "Status should be started or greater");
         uint8 prevStatus = uint8(campaigns[_index].status) - 1;
         return (campaignStatusCheckpoint[_index][prevStatus].Block, campaignStatusCheckpoint[_index][prevStatus].Timestamp);
     }

     function addCampaign(bytes32 _name, bytes32 _artistName,bytes32 _imageURL, address _artistAddr, uint8 _numNFTs, uint _rewardPerBlock) 
        external 
        checkRole(CAMPAIGN_ADMIN_ROLE, msg.sender, "Caller is not campaign admin")
    {
        
        // require(_name != "","must have name");
        // require(_artistName != "","artist must have name");
        // require(_artistAddr != address(0),"invalid address");
        Campaign memory campaign = Campaign(Status.Created, _name, _artistName, _artistAddr,_imageURL, _numNFTs, _rewardPerBlock);
        campaigns.push(campaign);

        console.log("Name is %s ", campaigns.length);
        campaignStatusCheckpoint[numCampaigns][uint8(Status.Created)] = StatusCheckpoint({Block: block.number, Timestamp:block.timestamp});
        numCampaigns++;
    }

    function getCampaignName(uint _index) external view returns (bytes32) {
        return campaigns[_index].name;
    }
    function getNumCampaigns() external view returns (uint) {
        return numCampaigns;
    }
    function updateCampaignStatus(uint _index, uint8 _newStatus) 
        external
        checkRole(CAMPAIGN_ADMIN_ROLE, msg.sender, "Caller is not campaign admin")  
        returns (bool) 
    {
        require(campaigns[_index].status < Status(_newStatus), "invalid new status");
        campaignStatusCheckpoint[_index][uint8(_newStatus)] = StatusCheckpoint({Block: block.number, Timestamp:block.timestamp});
        campaigns[_index].status = Status(_newStatus);
        return true;
    }

    function getNumNFTs(uint _index) external view returns (uint8) {
        return campaigns[_index].numNFTs;
    }

    function getVotingBlock(uint _index) external view returns (uint) {
        require(campaignStatusCheckpoint[_index][uint8(Status.Voting)].Block != 0, "invalid status for the campaign");
        return campaignStatusCheckpoint[_index][uint8(Status.Voting)].Block;
    }

    function getUploadBlock(uint _index) external view returns (uint) {
         require(campaignStatusCheckpoint[_index][uint8(Status.Upload)].Block != 0, "invalid status for the campaign");
        return campaignStatusCheckpoint[_index][uint8(Status.Upload)].Block;
    } 
    function isCampaignStarted(uint _index) external view returns (bool) {
        return campaigns[_index].status == Status.Started;
    }    
    function getRewardPerBlock(uint _index) external view returns (uint) {
        return campaigns[_index].rewardPerBlock;
    }
    
}