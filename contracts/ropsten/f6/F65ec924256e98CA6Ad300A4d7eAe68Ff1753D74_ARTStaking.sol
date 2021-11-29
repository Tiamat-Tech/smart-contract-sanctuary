//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct ERC1155NFT {
  address nftAddress;
  uint256 nftID;
  uint256 reward;
  uint256 lastBlock;
}

contract ARTStaking is IERC1155Receiver {
  // Holds all NFTs
  ERC1155NFT[] private allNFTs;

  //keep record of the owner of NFT
  mapping(address => mapping(address => ERC1155NFT[])) private nftBank;

  // Total Rewards to be distributed
  uint256 public totalRewards;

  // duration of staking period
  uint256 public totalBlocks;

  // Reward Token Address, this contract must have reward tokens in it
  address public rewardToken;

  // Block when rewards will be ended
  uint256 public rewardEndBlock;

  uint256 public rewardsPerBlock;

  // rank => weight
  mapping(uint256 => uint256) public weightOfRank;
  // rank total Usage
  mapping(uint256 => uint256) public rankUsage;

  uint256 public totalUsageWithWeight = 0;

  address public owner;

  using EnumerableSet for EnumerableSet.AddressSet;

  // Address of allowed NFT's
  EnumerableSet.AddressSet private allowedNfts;

  constructor(
    uint256 _totalRewards,
    uint256 _totalBlocks,
    address _rewardToken,
    address[] memory _allowedNfts
  ) {
    totalRewards = _totalRewards;
    totalBlocks = _totalBlocks;
    rewardToken = _rewardToken;
    rewardsPerBlock = totalRewards / totalBlocks;
    rewardEndBlock = block.number + _totalBlocks;
    owner = msg.sender;

    console.log("totalBlocks", totalBlocks);
    console.log("totalRewards", totalRewards);
    console.log("rewardsPerBlock", rewardsPerBlock);

    weightOfRank[0] = 4;
    weightOfRank[1] = 3;
    weightOfRank[2] = 3;
    weightOfRank[3] = 2;
    weightOfRank[4] = 2;
    weightOfRank[5] = 2;
    weightOfRank[6] = 1;
    weightOfRank[7] = 1;
    weightOfRank[8] = 1;
    weightOfRank[9] = 1;

    for (uint256 i = 0; i < _allowedNfts.length; i++) {
      allowedNfts.add(_allowedNfts[i]);
    }
  }

  // stake NFT,
  function stake(uint256 _nftID, address _nftAddress) external {
    console.log("stake(): _nftAddress", _nftAddress);
    console.log("stake(): _nftID", _nftID);
    console.log("stake(): msg.sender", msg.sender);

    require(allowedNfts.contains(_nftAddress), "only ART's are allowed");
    require(_nftID <= 9, "upto 9 rank is allowed");

    //check if it is within the staking period
    require(block.number < rewardEndBlock, "reward period has ended");
    
    //check if the owner has approved the contract to safe transfer the NFT
    require(IERC1155(_nftAddress).isApprovedForAll(msg.sender, address(this)), "you must approve this contract to safe transfer the NFT");

    ERC1155NFT memory nft = ERC1155NFT({
      nftAddress: _nftAddress,
      nftID: _nftID,
      reward: 0,
      lastBlock: Math.min(block.number, rewardEndBlock)
    });

    nftBank[msg.sender][_nftAddress].push(nft);
    allNFTs.push(nft);
    // update rank
    increaseRank(_nftID);
    console.log("stake():  Total Staked", allNFTs.length);
    IERC1155(_nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      _nftID,
      1,
      "0x0"
    );
  }

  function unstake(uint256 _nftID, address _nftAddress) external {
    console.log("unstake(): nftType", _nftAddress);
    console.log("unstake(): tokenId", _nftID);
    console.log("unstake(): msg.sender", msg.sender);

    require(
      checkIFExists(nftBank[msg.sender][_nftAddress], _nftID),
      "token not deposited"
    );

    decreaseRank(_nftID);
    uint256 reward = _claimReward(_nftAddress, _nftID);

    deleteNFTFromBank(_nftAddress, msg.sender, _nftID);
    removeNFTFromArray(_nftAddress, _nftID);

    console.log("claimReward: Total Reward reward", reward);

    IERC20(rewardToken).transfer(msg.sender, reward);

    IERC1155(_nftAddress).safeTransferFrom(
      address(this),
      msg.sender,
      _nftID,
      1,
      "0x0"
    );
    console.log("unstake():  Total Staked", allNFTs.length);
  }

  function viewReward(uint256 _nftID, address _nftAddress)
    external
    view
    returns (uint256)
  {
    uint256 calculatedReward = 0;
    for (uint256 i = 0; i < allNFTs.length; i++) {
      if (allNFTs[i].nftID == _nftID && allNFTs[i].nftAddress == _nftAddress) {
        console.log("block.number", block.number);

        uint256 rewardPerShare = 0;

        if (totalUsageWithWeight > 0) {
          rewardPerShare = (rewardsPerBlock / totalUsageWithWeight);
        } else {
          rewardPerShare = rewardsPerBlock;
        }

        calculatedReward =
          allNFTs[i].reward +
          (weightOfRank[allNFTs[i].nftID] *
            rewardPerShare *
            (Math.min(block.number, rewardEndBlock) - allNFTs[i].lastBlock));
      }
    }
    return calculatedReward;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    pure
    override
    returns (bool)
  {
    return
      interfaceId == type(IERC1155Receiver).interfaceId ||
      interfaceId == type(IERC20).interfaceId;
  }

  function onERC1155Received(
    address,
    address,
    uint256,
    uint256,
    bytes memory
  ) public pure override returns (bytes4) {
    return
      bytes4(
        keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")
      );
  }

  function onERC1155BatchReceived(
    address,
    address,
    uint256[] memory,
    uint256[] memory,
    bytes memory
  ) public pure override returns (bytes4) {
    return
      bytes4(
        keccak256(
          "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
        )
      );
  }

  function checkIFExists(ERC1155NFT[] memory _nfts, uint256 _nftID)
    internal
    pure
    returns (bool)
  {
    for (uint256 i = 0; i < _nfts.length; i++) {
      if (_nfts[i].nftID == _nftID) {
        return true;
      }
    }
    return false;
  }

  function viewStakedNFTIds(address _owner, address _nftAddress)
    public
    view
    returns (uint256[] memory)
  {
    uint256[] memory ids = new uint256[](nftBank[_owner][_nftAddress].length);
    for (uint256 i = 0; i < nftBank[_owner][_nftAddress].length; i++) {
      ids[i] = (nftBank[_owner][_nftAddress][i].nftID);
    }
    return ids;
  }

  function viewStakedNFTs(address _owner)
    public
    view
    returns (address[] memory)
  {
    address[] memory nftTypes = new address[](15);
    for (uint256 i = 0; i < allowedNfts.length(); i++) {
      if (nftBank[_owner][allowedNfts.at(i)].length > 0) {
        nftTypes[i] = allowedNfts.at(i);
      }
    }
    return nftTypes;
  }

  function viewAllowedNFTs() public view returns (address[] memory) {
    address[] memory nftTypes = new address[](15);
    for (uint256 i = 0; i < allowedNfts.length(); i++) {
      nftTypes[i] = allowedNfts.at(i);
    }
    return nftTypes;
  }

  function deleteNFTFromBank(
    address _nftAddress,
    address _owner,
    uint256 _nftID
  ) internal {
    uint256 indexToDelete;

    for (uint256 i = 0; i < nftBank[_owner][_nftAddress].length; i++) {
      if (nftBank[_owner][_nftAddress][i].nftID == _nftID) {
        indexToDelete = i;
        nftBank[_owner][_nftAddress][indexToDelete] = nftBank[_owner][
          _nftAddress
        ][nftBank[_owner][_nftAddress].length - 1];
        nftBank[_owner][_nftAddress].pop();
      }
    }
  }

  function calculateRewards() internal {
    for (uint256 i = 0; i < allNFTs.length; i++) {
      uint256 rewardPerShare = 0;

      if (totalUsageWithWeight > 0) {
        rewardPerShare = (rewardsPerBlock / totalUsageWithWeight);
      } else {
        rewardPerShare = rewardsPerBlock;
      }
      console.log("-------------------calculate reward--", i);
      console.log("--- ------allNFTs.length--", allNFTs.length);

      console.log("--- ------totalUsageWithWeight--", totalUsageWithWeight);
      console.log("--- ------shareOfReward--", rewardPerShare);
      console.log(
        "--- ------total Block--",
        block.number - allNFTs[i].lastBlock
      );
      console.log("--- ------rank --", allNFTs[i].nftID);
      console.log("--- ------existing reward --", allNFTs[i].reward);

      // reward = (weightofrank * rewardPerShare) * totalBlocks
      
      uint smallerBlock = Math.min(block.number, rewardEndBlock);
      
      allNFTs[i].reward += (weightOfRank[allNFTs[i].nftID] *
        rewardPerShare *
        (smallerBlock - allNFTs[i].lastBlock));

      console.log("--- ------new reward --", allNFTs[i].reward);

      allNFTs[i].lastBlock = smallerBlock;

      console.log("--- ------reward --", allNFTs[i].reward);
    }
  }

  function _claimReward(address _nftAddress, uint256 _nftID)
    internal
    returns (uint256)
  {
    //check if msg.sender is owner
    require(
      checkIFExists(nftBank[msg.sender][_nftAddress], _nftID),
      "not owner of mentioned NFT"
    );

    uint256 reward = 0;

    for (uint256 i = 0; i < allNFTs.length; i++) {
      if (allNFTs[i].nftID == _nftID && allNFTs[i].nftAddress == _nftAddress) {
        reward = allNFTs[i].reward;
        allNFTs[i].reward = 0;
      }
    }

    return reward;
  }

  function increaseRank(uint256 _rank) internal {
    calculateRewards();
    
    //increase this NFT's rank counter
    rankUsage[_rank] = rankUsage[_rank] + 1;
    
    //totalUsage = number of that rank used
    totalUsageWithWeight = totalUsageWithWeight + (1 * weightOfRank[_rank]);
  }

  function decreaseRank(uint256 _rank) internal {
    calculateRewards();
    rankUsage[_rank] = rankUsage[_rank] - 1;
    totalUsageWithWeight = totalUsageWithWeight - (1 * weightOfRank[_rank]);
  }

  function expectedRewardTillEnd(uint256 _nftID)
    external
    view
    returns (uint256)
  {
    uint256 rewardPerShare = 0;
    uint256 weight = 0;

    
    if (rankUsage[_nftID]<=0){
      weight = totalUsageWithWeight + weightOfRank[_nftID];
    } else{
      weight = weightOfRank[_nftID];
    }

    if (weight > 0) {
      rewardPerShare = (rewardsPerBlock / weight);
    } else {
      rewardPerShare = rewardsPerBlock;
    }
    return
      weightOfRank[_nftID] * rewardPerShare * (rewardEndBlock - block.number);
  }

  function addNFTtoArray(ERC1155NFT memory _nft) internal {
    allNFTs.push(_nft);
  }

  function removeNFTFromArray(address _nftAddress, uint256 _nftID) internal {
    uint256 indexToDelete = 0;
    for (uint256 i = 0; i < allNFTs.length; i++) {
      if (allNFTs[i].nftID == _nftID && allNFTs[i].nftAddress == _nftAddress) {
        indexToDelete = i;
        allNFTs[indexToDelete] = allNFTs[allNFTs.length - 1];
        allNFTs.pop();
      }
    }
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "only owner can do this action");
    _;
  }

  function withdrawToken(address _tokenContract, uint256 _amount)
    external
    onlyOwner
  {
    require(_tokenContract != rewardToken, "rewards token not allowed");
    IERC20 tokenContract = IERC20(_tokenContract);
    tokenContract.transfer(msg.sender, _amount);
  }

  function withdrawEth() external onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }

  function burnRewardToken() external {
    require(rewardEndBlock < block.number, "reward period is still on");
    require(allNFTs.length == 0, "NFT's are still staked");
    IERC20 tokenContract = IERC20(rewardToken);
    tokenContract.transfer(
      address(0x000000000000000000000000000000000000dEaD),
      tokenContract.balanceOf(address(this))
    );
  }
}