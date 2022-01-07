// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GenesisNFTStaking is OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeMath for uint8;

    uint256 public lensPerBlock;

    IERC20 public lensContract;

    IERC721Enumerable public genesisNFTContract;

    uint256 public startBlock;

    bool public withdrawEnable;

    // NFTId => claimedReward
    mapping (uint256 =>  uint256) claimedRewards;

    event Claim(address indexed user, uint256 indexed nftId, uint256 amount);

    function initialize(
        uint256 _lensPerBlock,
        IERC20 _lensContract,
        IERC721Enumerable _genesisNFTContract
    )  public initializer {
        lensPerBlock = _lensPerBlock;
        lensContract = _lensContract;
        genesisNFTContract = _genesisNFTContract;

        withdrawEnable = false;
        startBlock = block.number;

        __Ownable_init();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setStartBlock(uint256 _startBlock) external onlyOwner {
        startBlock = _startBlock;
    }

    function withdrawLens(uint256 amount) external onlyOwner {
        require(amount <= lensContract.balanceOf(address(0)), "Amount greater than balance");
        lensContract.transfer(msg.sender, amount);
    }

    function flipWithdrawEnable() external onlyOwner {
        withdrawEnable = !withdrawEnable;
    }

    function userNFTs() public view virtual returns (uint256[] memory) {
        uint256 addressNFTAmount = genesisNFTContract.balanceOf(msg.sender);
        uint256[] memory nftIds = new uint256[](addressNFTAmount);

        for (uint256 i = 0; i < addressNFTAmount; i++) {
            nftIds[i] = genesisNFTContract.tokenOfOwnerByIndex(msg.sender, i);
        }

        return nftIds;
    }

    function pendingRewards() public view virtual returns (uint256) {
        uint256[] memory nfts = userNFTs();
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < nfts.length; i++) {
            totalRewards = totalRewards.add(pendingRewardsByNftId(nfts[i]));
        }
        return totalRewards;
    }

    function pendingRewardsByNftId(uint256 nftId) public view virtual returns (uint256) {
        uint256 totalRewards = (block.number.sub(startBlock)).mul(lensPerBlock);
        return totalRewards.sub(claimedRewards[nftId]);
    }

    function _claimRewardsByNftIds(uint256[] memory nftIds) internal {
        uint256 totalPending = 0;

        for (uint256 i = 0; i < nftIds.length; i++) {
            require(genesisNFTContract.ownerOf(nftIds[i]) == msg.sender, 'You are not owner of NFT');
            uint256 pending = pendingRewardsByNftId(nftIds[i]);
            totalPending = totalPending.add(pending);
            claimedRewards[nftIds[i]] = claimedRewards[nftIds[i]].add(pending);

            if (pending > 0) {
                emit Claim(msg.sender, nftIds[i], totalPending);
            }
        }

        lensContract.transfer(msg.sender, totalPending);
    }

    function claimRewardsByNftIds(uint256[] memory nftIds) external {
        _claimRewardsByNftIds(nftIds);
    }


    function claimRewards() external {
        _claimRewardsByNftIds(userNFTs());
    }
}