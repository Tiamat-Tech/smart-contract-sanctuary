// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Ink.sol";

contract StakingPool is IERC721Receiver, Ownable, Pausable {
    using EnumerableSet for EnumerableSet.UintSet;

    event StakeStarted(address indexed user, uint256 indexed tokenId);
    event StakeStopped(address indexed user, uint256 indexed tokenId);
    event UtilityAddrSet(address from, address addr);

    UtilityToken private _utilityToken;

    struct StakedInfo {
        uint256 lastUpdate;
    }

    mapping(uint256 => StakedInfo) private tokenInfo;
    mapping(address => EnumerableSet.UintSet) private stakedTko;
    address private _tkoContract;
    uint256 public rewardUnit = 1500;
    
    modifier masterContract() {
        require(
            msg.sender == _tkoContract,
            "Master Contract can only call Staking Contract"
        );
        _;
    }
    
    modifier notPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    constructor(address _tkoAddr) {
        _tkoContract = _tkoAddr;
    }

    function setUtilitytoken(address _addr) external onlyOwner {
        _utilityToken = UtilityToken(_addr);
        emit UtilityAddrSet(address(this), _addr);
    }
    
    function changeRewardUnit(uint256 _rewardUnit) external onlyOwner {
        rewardUnit = _rewardUnit;
    }

    function pause(bool val) public onlyOwner {
        if (val == true) {
            _pause();
            return;
        }
        _unpause();
    }

    function startStaking(address _user, uint256 _tokenId)
        external
        notPaused
        masterContract
    {
        require(!stakedTko[_user].contains(_tokenId), "Already staked");
        tokenInfo[_tokenId].lastUpdate = block.timestamp;
        stakedTko[_user].add(_tokenId);

        emit StakeStarted(_user, _tokenId);   
    }
    // function startStaking(address _user, uint256[] memory _tokenIds)
    //     external
    //     masterContract
    // {
    //     require(_tokenIds.length>=4, "4 NFTs min to stake");
        
    //     for (uint256 i = 0; i < _tokenIds.length; i++) {
    //         require(!stakedTko[_user].contains(_tokenIds[i]), "Already staked");
    //     }
    //     for (uint256 i = 0; i < _tokenIds.length; i++) {
    //         tokenInfo[_tokenIds[i]].lastUpdate = block.timestamp;
    //         stakedTko[_user].add(_tokenIds[i]);

    //         emit StakeStarted(_user, _tokenIds[i]);
    //     }
        
    // }

    function stopStaking(address _user, uint256 _tokenId)
        external
        masterContract
    {
        require(stakedTko[_user].contains(_tokenId), "You're not the owner");
        uint256 interval = block.timestamp - tokenInfo[_tokenId].lastUpdate;
        uint256 reward = rewardUnit * interval / 86400;
        _utilityToken.reward(_user, reward);
        delete tokenInfo[_tokenId];
        stakedTko[_user].remove(_tokenId);

        emit StakeStopped(_user, _tokenId);
    }

    function stakedTokensOf(address _user)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory tokens = new uint256[](stakedTko[_user].length());
        for (uint256 i = 0; i < stakedTko[_user].length(); i++) {
            tokens[i] = stakedTko[_user].at(i);
        }
        return tokens;
    }

    function getClaimableToken(address _user) public view returns (uint256) {
        uint256[] memory tokens = stakedTokensOf(_user);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 interval = block.timestamp -
                tokenInfo[tokens[i]].lastUpdate;
            uint256 reward = rewardUnit * interval / 86400;

            totalAmount += reward;
        }

        return totalAmount;
    }

    function getReward() external {
        _utilityToken.reward(msg.sender, getClaimableToken(msg.sender));
        for (uint256 i = 0; i < stakedTko[msg.sender].length(); i++) {
            uint256 tokenId = stakedTko[msg.sender].at(i);
            tokenInfo[tokenId].lastUpdate = block.timestamp;
        }
    }

    /**
     * ERC721Receiver hook for single transfer.
     * @dev Reverts if the caller is not the whitelisted NFT contract.
     */
    function onERC721Received(
        address, /*operator*/
        address, /*from*/
        uint256, /* tokenId */
        bytes calldata /*data*/
    ) external view override returns (bytes4) {
        require(
            _tkoContract == msg.sender,
            "You can stake only Tko"
        );
        return this.onERC721Received.selector;
    }
}