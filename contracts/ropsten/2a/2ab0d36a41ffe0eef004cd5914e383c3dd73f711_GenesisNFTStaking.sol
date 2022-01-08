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

    uint256 public totalNFTs;

    bool public withdrawEnable;

    // NFTId => claimedReward
    mapping (uint256 =>  uint256) claimedRewards;

    event Claim(address indexed user, uint256 indexed nftId, uint256 amount);

    function initialize(
        uint256 _lensPerBlock,
        uint256 _totalNFTs,
        IERC20 _lensContract,
        IERC721Enumerable _genesisNFTContract
    )  public initializer {
        lensPerBlock = _lensPerBlock;
        lensContract = _lensContract;
        genesisNFTContract = _genesisNFTContract;

        withdrawEnable = false;
        startBlock = block.number;
        totalNFTs = _totalNFTs;

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
        require(amount <= lensContract.balanceOf(address(this)), "Amount greater than balance");
        lensContract.transfer(msg.sender, amount);
    }

    modifier withdrawIsEnabled() {
        require(withdrawEnable, "Withdraw is disable");
        _;
    }

    function flipWithdrawEnable() external onlyOwner {
        withdrawEnable = !withdrawEnable;
    }

    function userNFTs(address addr) public view virtual returns (uint256[] memory) {
        uint256 addressNFTAmount = genesisNFTContract.balanceOf(addr);
        uint256[] memory nftIds = new uint256[](addressNFTAmount);

        for (uint256 i = 0; i < addressNFTAmount; i++) {
            nftIds[i] = genesisNFTContract.tokenOfOwnerByIndex(addr, i);
        }

        return nftIds;
    }

    function pendingRewards(address addr) public view virtual returns (uint256) {
        uint256[] memory nfts = userNFTs(addr);
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < nfts.length; i++) {
            totalRewards = totalRewards.add(pendingRewardsByNftId(nfts[i]));
        }
        return totalRewards;
    }

    function pendingRewardsByNftId(uint256 nftId) public view virtual returns (uint256) {
        uint256 lastBlock = block.number;
        uint256 endBlock = lensContract.balanceOf(address(this)).div(totalNFTs.mul(lensPerBlock));
        if (lastBlock > endBlock) {
            lastBlock = endBlock;
        }

        if (lastBlock < block.number) {
            lastBlock = block.number;
        }

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

    function claimRewardsByNftIds(uint256[] memory nftIds) external withdrawIsEnabled {
        _claimRewardsByNftIds(nftIds);
    }

    function claimRewards() external withdrawIsEnabled {
        _claimRewardsByNftIds(userNFTs(msg.sender));
    }
}