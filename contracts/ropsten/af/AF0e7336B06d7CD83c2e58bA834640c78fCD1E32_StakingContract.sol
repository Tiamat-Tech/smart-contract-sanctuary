// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is Ownable {
    mapping(address => address) private NFTToRewardToken;
    mapping(address => uint256) private NFTToRewardAmount;

    struct StakedNFT {
        address NFT;
        uint256 id;
        uint256 lastWithdraw;
    }

    mapping(address => StakedNFT[]) private accountToNFTsStaked;
    
    //////////
    // Getters

    function getNFTToRewardToken(address _nft) view external returns(address) {
        return NFTToRewardToken[_nft];
    }

    function getNFTToRewardAmount(address _nft) view external returns(uint256) {
        return NFTToRewardAmount[_nft];
    }

    function getStakedNFTsByAccount(address _account) view external returns(StakedNFT[] memory) {
        return accountToNFTsStaked[_account];
    }

    function getRewardAmountPerNFT(uint256 _lastWithdraw, address _nft) view public returns(uint256) {
        uint256 amount = NFTToRewardAmount[_nft];
        uint256 timeInBetween = block.timestamp - _lastWithdraw; 

        return (amount * timeInBetween);
    }

    //

    function stakeNFT(address _nft, uint256 _id) external {
        IERC721 NFT = IERC721(_nft);

        NFT.transferFrom(msg.sender, address(this), _id);

        StakedNFT memory newStake = StakedNFT(_nft, _id, block.timestamp);
        accountToNFTsStaked[msg.sender].push(newStake);
    }

    function withdrawAllEarnings() external {
        for (uint256 i=0;i<accountToNFTsStaked[msg.sender].length;i++) {
            withdrawSpecificEarning(i);
        }
    }

    function withdrawSpecificEarning(uint256 _i) public {
        if (accountToNFTsStaked[msg.sender][_i].NFT != address(0) && NFTToRewardToken[accountToNFTsStaked[msg.sender][_i].NFT] != address(0)) {
            StakedNFT memory stake = accountToNFTsStaked[msg.sender][_i];
            
            uint256 amount = getRewardAmountPerNFT(stake.lastWithdraw, stake.NFT);

            IERC20 token = IERC20(NFTToRewardToken[stake.NFT]);
            token.transfer(msg.sender, amount);

            accountToNFTsStaked[msg.sender][_i].lastWithdraw = block.timestamp;
        }
    }

    function unstakeAllNFTs() external {
        for (uint256 i=0;i<accountToNFTsStaked[msg.sender].length;i++) {            
            unstakeNFT(i);
        }

        delete accountToNFTsStaked[msg.sender];
    }

    function unstakeNFT(uint256 _i) public {
        if (accountToNFTsStaked[msg.sender][_i].NFT != address(0) && NFTToRewardToken[accountToNFTsStaked[msg.sender][_i].NFT] != address(0)) {
            withdrawSpecificEarning(_i);

            StakedNFT memory stake = accountToNFTsStaked[msg.sender][_i];

            IERC721 NFT = IERC721(stake.NFT);

            NFT.transferFrom(address(this), msg.sender, stake.id);

            delete accountToNFTsStaked[msg.sender][_i];
        }
    }

    //////////////////
    // Owner functions

    function setNFTRewardToken(address _nft, address _token) external onlyOwner() {
        NFTToRewardToken[_nft] = _token;
    }

    function setNFTRewardAmount(address _nft, uint256 _amount) external onlyOwner() {
        NFTToRewardAmount[_nft] = _amount;
    }

    function withdrawTokens(address _token, address _receiver, uint256 _amount) external onlyOwner() {
        IERC20 token = IERC20(_token);

        token.transfer(_receiver, _amount);
    }
}