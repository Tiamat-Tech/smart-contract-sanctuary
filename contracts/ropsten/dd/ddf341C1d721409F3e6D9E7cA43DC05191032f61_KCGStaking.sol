// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KCGStaking is Ownable, ReentrancyGuard {
    uint256 public constant DAY = 5;
    uint256 public constant FOURTY_FIVE_DAYS = 45 * DAY;
    uint256 public constant NINETY_DAYS = 90 * DAY;
    uint256 public constant ONE_HUNDREDS_EIGHTY_DAYS = 180 * DAY;

    address public KCGAddress = 0x3aE9a5Df9B4c1C915b847308b2C8Fb6C5E73F800;

    bool public emergencyUnstakePaused = true;

    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    struct TokenOwner {
        address tokenOwner;
        uint256 tokenId;
        uint256 endingTimestamp;
    }

    TokenOwner[] public tokenOwners;

    mapping(address => uint) public numOfTokenStaked;

    event Staked(address owner, uint256 amount, uint256 timeframe);

    event Unstaked(address owner, uint256 amount);
    
    event EmergencyUnstake(address indexed user, uint256 tokenId);

    constructor() {}

    modifier checkStakingTimeframe(uint256 timeframe) {
        require(timeframe == FOURTY_FIVE_DAYS || timeframe == NINETY_DAYS || timeframe == ONE_HUNDREDS_EIGHTY_DAYS,
        "invalid staking timeframe");
        _;
    }

    function stake(
        uint256 tokenId,
        uint256 timeframe
    )
        external
        checkStakingTimeframe(timeframe)
    {
        _stake(msg.sender, tokenId, timeframe);
    }

    function stakeBatch(uint256[] memory tokenIds, uint256 timeframe)
        external
        checkStakingTimeframe(timeframe)
    {
        for (uint i = 0; i < tokenIds.length; i++) {
            _stake(msg.sender, tokenIds[i], timeframe);
        }
    }

    function stakeAll(uint256 timeframe)
        external
        checkStakingTimeframe(timeframe)
    {
        uint256 balance = IERC721Enumerable(KCGAddress).balanceOf(msg.sender);
        for (uint i = 0; i < balance; i++) {
            _stake(msg.sender, IERC721Enumerable(KCGAddress).tokenOfOwnerByIndex(msg.sender,i), timeframe);
        }
    }

    function _stake(
        address _user,
        uint256 _tokenId,
        uint256 _timeframe
    )
        internal
    {
        require(IERC721Enumerable(KCGAddress).ownerOf(_tokenId) == msg.sender, "sender must own the NFT");
        uint256 endingTimestamp = block.timestamp + _timeframe;

        tokenOwners[_tokenId] = TokenOwner(_user, _tokenId, endingTimestamp);
        // numOfTokenStaked[_user] = numOfTokenStaked[_user] + 1;
        IERC721Enumerable(KCGAddress).safeTransferFrom(
            _user,
            address(this),
            _tokenId
        );

        emit Staked(_user, _tokenId, _timeframe);
    }

    function unstake(
        uint256 _tokenId
    ) 
        external 
    {
        _unstake(msg.sender, _tokenId);
    }

    function unstakeBatch(
        uint256[] memory tokenIds
    )
        external
    {
        for (uint i = 0; i < tokenIds.length; i++) {
            _unstake(msg.sender, tokenIds[i]);
        }
    }

    function _unstake(
        address _user,
        uint256 _tokenId
    ) 
        internal 
    {
        require(block.timestamp >= tokenOwners[_tokenId].endingTimestamp, "still locked");
        require(
            tokenOwners[_tokenId].tokenOwner == msg.sender,
            "Sender must have staked tokenId"
        );
        
        delete tokenOwners[_tokenId];
        numOfTokenStaked[_user]--;
        IERC721Enumerable(KCGAddress).safeTransferFrom(
            address(this),
            _user,
            _tokenId
        );

        emit Unstaked(_user, _tokenId);
    }

    function getStakers(address _user) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](numOfTokenStaked[_user]);
        uint256[] memory expiries = new uint256[](numOfTokenStaked[_user]);
        uint256 counter = 0;
        for(uint i = 0; i < tokenOwners.length; i++) {
            if (tokenOwners[i].tokenOwner == _user) {
                tokenIds[counter] = tokenOwners[i].tokenId;
                expiries[counter] = tokenOwners[i].endingTimestamp;
                counter++;
            }
        }
        return (tokenIds, expiries);
    }

    function onERC721Received(
        address,
        address,
        uint256
    )
        public pure returns (bytes4)
    {
        return _ERC721_RECEIVED;
    }

    // MIGRATION ONLY.
    function setKCGNFTContract(address _address) public onlyOwner {
        KCGAddress = _address;
    }

    // EMERGENCY ONLY.
    function setEmergencyUnstakePause(bool _setEmergencyUnstakePause)
        public
        onlyOwner
    {
        emergencyUnstakePaused = _setEmergencyUnstakePause;
    }

    function emergencyUnstake(uint256 _tokenId) external {
        require(!emergencyUnstakePaused, "public mint paused");
        require(
            tokenOwners[_tokenId].tokenOwner == msg.sender,
            "Sender must have staked tokenId"
        );
        _unstake(msg.sender, _tokenId);
        emit EmergencyUnstake(msg.sender, _tokenId);
    }

}