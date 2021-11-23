//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/*TODO onERC1155BatchReceived
include burn function if rewards are left 
*/

// comments: owner to index of allNFts
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
  uint256 private totalRewards;

  // duration of staking period
  uint256 private totalBlocks;

  // Reward Token Address, this contract must have reward tokens in it
  address private rewardToken;

  // Block when rewards will be ended
  uint256 private rewardEndBlock;

  uint256 private rewardsPerBlock;

  // rank => weight
  mapping(uint256 => uint256) private weightOfRank;
  // rank total Usage
  mapping(uint256 => uint256) private rankUsage;

  uint256 private totalUsage;
  uint256 private totalUsageWithWeight = 0;

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

    console.log("deployed");
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
    //TODO fetch rank
    console.log("stake(): _nftAddress", _nftAddress);
    console.log("stake(): _nftID", _nftID);
    console.log("stake(): msg.sender", msg.sender);

    require(_nftID <= 9, "upto 9 rank is allowed");

    IERC1155(_nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      _nftID,
      1,
      "0x0"
    );

    // TODO: test this, its deepcopy or reference

    ERC1155NFT memory nft = ERC1155NFT({
      nftAddress: _nftAddress,
      nftID: _nftID,
      reward: 0,
      lastBlock: Math.min(block.number, rewardEndBlock)
    });

    nftBank[msg.sender][_nftAddress].push(nft);

    // update rank
    addNFT(nft);
    increaseRank(_nftID);
    console.log("stake():  Total Staked", allNFTs.length);
  }

  function unstake(uint256 _nftID, address _nftAddress) external {
    console.log("unstake(): nftType", _nftAddress);
    console.log("unstake(): tokenId", _nftID);
    console.log("unstake(): msg.sender", msg.sender);

    require(
      checkIFExists(nftBank[msg.sender][_nftAddress], _nftID),
      "token not deposited"
    );

    IERC1155(_nftAddress).safeTransferFrom(
      address(this),
      msg.sender,
      _nftID,
      1,
      "0x0"
    );
    decreaseRank(_nftID);
    _claimReward(_nftAddress, _nftID);

    //TODO rename these functions ndeleteNFT/removeNFT
    deleteNFT(_nftAddress, msg.sender, _nftID);
    removeNFT(_nftAddress, _nftID);

    console.log("unstake():  Total Staked", allNFTs.length);
  }

  function claimReward(uint256 _nftID, address _nftAddress) external {
    _claimReward(_nftAddress, _nftID);
  }

  function viewReward(uint256 _nftID, address _nftAddress)
    external
    view
    returns (uint256)
  {
    for (uint256 i = 0; i < allNFTs.length; i++) {
      if (allNFTs[i].nftID == _nftID && allNFTs[i].nftAddress == _nftAddress) {
        console.log("block.number", block.number);
        return (allNFTs[i].reward +
          (Math.min(block.number, rewardEndBlock) - allNFTs[i].lastBlock) *
          (_nftID * (rewardsPerBlock / totalUsageWithWeight)));
      }
    }
    return 0;
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
    address, /*_operator*/
    address, /*_from*/
    uint256[] memory, /*_ids*/
    uint256[] memory, /*_values*/
    bytes memory /*_data*/
  ) public pure override returns (bytes4) {
    return 0xbc197c81;
  }

  function checkIFExists(ERC1155NFT[] memory _nfts, uint256 nftID)
    internal
    pure
    returns (bool)
  {
    for (uint256 i = 0; i < _nfts.length; i++) {
      if (_nfts[i].nftID == nftID) {
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
       if (nftBank[_owner][allowedNfts.at(i)].length >0){
         nftTypes[i] = allowedNfts.at(i);
      }
    }
    return nftTypes;
  }

  function deleteNFT(
    address _nftAddress,
    address _owner,
    uint256 _nftID
  ) internal {
    uint256 indexToDelete;

    for (uint256 i = 0; i < nftBank[_owner][_nftAddress].length; i++) {
      if (nftBank[_owner][_nftAddress][i].nftID == _nftID) {
        indexToDelete = i;
      }
      nftBank[_owner][_nftAddress][indexToDelete] = nftBank[_owner][
        _nftAddress
      ][nftBank[_owner][_nftAddress].length - 1];
      nftBank[_owner][_nftAddress].pop();
    }
  }

  function calculateRewards() internal {
    for (uint256 i = 0; i < allNFTs.length; i++) {
      uint256 shareOfReward = 0;

      if (totalUsageWithWeight > 0) {
        shareOfReward = (rewardsPerBlock / totalUsageWithWeight);
      } else {
        shareOfReward = rewardsPerBlock;
      }
      console.log("-------------------calculate reward--", i);
      console.log("--- ------allNFTs.length--", allNFTs.length);

      console.log("--- ------totalUsageWithWeight--", totalUsageWithWeight);
      console.log("--- ------shareOfReward--", shareOfReward);
      console.log(
        "--- ------total Block--",
        block.number - allNFTs[i].lastBlock
      );
      console.log("--- ------rank --", allNFTs[i].nftID);
      console.log("--- ------existing reward --", allNFTs[i].reward);

      allNFTs[i].reward =
        allNFTs[i].reward +
        (weightOfRank[allNFTs[i].nftID] *
          shareOfReward *
          (Math.min(block.number, rewardEndBlock) - allNFTs[i].lastBlock));
      allNFTs[i].lastBlock = Math.min(block.number, rewardEndBlock);
      console.log("--- ------reward --", allNFTs[i].reward);
    }
  }

  function _claimReward(address _nftAddress, uint256 _nftID) internal {
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

    console.log("claimReward: Total Reward reward", reward);

    IERC20(rewardToken).transfer(msg.sender, reward);
  }

  function increaseRank(uint256 _rank) internal {
    rankUsage[_rank] = rankUsage[_rank] + 1;
    totalUsageWithWeight = totalUsageWithWeight + 1 * weightOfRank[_rank];
    // console.log("totalUsageWithWeight", totalUsageWithWeight);
    calculateRewards();
  }

  function decreaseRank(uint256 _rank) internal {
    rankUsage[_rank] = rankUsage[_rank] - 1;
    totalUsageWithWeight = totalUsageWithWeight - 1 * weightOfRank[_rank];
    // console.log("totalUsageWithWeight", totalUsageWithWeight);
    calculateRewards();
  }

  function addNFT(ERC1155NFT memory _nft) internal {
    allNFTs.push(_nft);
  }

  function removeNFT(address _nftAddress, uint256 _nftID) internal {
    uint256 indexToDelete;
    for (uint256 i = 0; i < allNFTs.length; i++) {
      if (allNFTs[i].nftID == _nftID && allNFTs[i].nftAddress == _nftAddress) {
        indexToDelete = i;
      }
      allNFTs[indexToDelete] = allNFTs[allNFTs.length - 1];
      allNFTs.pop();
    }
  }
}