// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KCGStaking is Ownable, ReentrancyGuard {
    uint256 public constant DAY = 5;
    uint256 public constant FOURTY_FIVE_DAYS = 45 * DAY;
    uint256 public constant NINETY_DAYS = 90 * DAY;
    uint256 public constant ONE_HUNDREDS_EIGHTY_DAYS = 180 * DAY;

    address public KCGAddress = 0xf4616A3e97CE23679D33b2736cd26fE8C54B1A94;
    bool public emergencyUnstakePaused = true;

    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    struct stakeRecord {
        address tokenOwner;
        uint256 tokenId;
        uint256 endingTimestamp;
    }

    mapping(uint256 => stakeRecord) public stakingRecords;

    mapping(address => uint) public numOfTokenStaked;

    event Staked(address owner, uint256 amount, uint256 timeframe);

    event Unstaked(address owner, uint256 amount);
    
    event EmergencyUnstake(address indexed user, uint256 tokenId);

    constructor() {}

    modifier checkArgsLength(uint256[] calldata tokenIds, uint256[] calldata timeframe) {
        require(tokenIds.length == timeframe.length, "token ids and time frame must be same length");
        _;
    }

    modifier checkStakingTimeframe(uint256[] calldata timeframe) {
        for (uint i = 0; i < timeframe.length; i++) {
            uint256 period = timeframe[i];
            require(period == FOURTY_FIVE_DAYS || period == NINETY_DAYS || period == ONE_HUNDREDS_EIGHTY_DAYS,
        "invalid staking timeframe");
        }
        _;
    }

    function batchStake(uint256[] calldata tokenIds, uint256[] calldata timeframe)
        external
        checkStakingTimeframe(timeframe)
        checkArgsLength(tokenIds, timeframe)
    {
        for (uint i = 0; i < tokenIds.length; i++) {
            _stake(msg.sender, tokenIds[i], timeframe[i]);
        }
    }

    function batchRestake(uint256[] calldata tokenIds, uint256[] calldata timeframe)
        external
        checkStakingTimeframe(timeframe)
        checkArgsLength(tokenIds, timeframe)
    {
        for (uint i = 0; i < tokenIds.length; i++) {
            _restake(msg.sender, tokenIds[i], timeframe[i]);
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

        stakingRecords[_tokenId] = stakeRecord(_user, _tokenId, endingTimestamp);
        numOfTokenStaked[_user] = numOfTokenStaked[_user] + 1;
        IERC721Enumerable(KCGAddress).safeTransferFrom(
            _user,
            address(this),
            _tokenId
        );

        emit Staked(_user, _tokenId, _timeframe);
    }

    function _restake(
        address _user,
        uint256 _tokenId,
        uint256 _timeframe
    )
        internal
    {
        require(block.timestamp >= stakingRecords[_tokenId].endingTimestamp, "still locked");
        require(
            stakingRecords[_tokenId].tokenOwner == msg.sender,
            "Sender must have staked tokenId"
        );

        uint256 endingTimestamp = block.timestamp + _timeframe;
        stakingRecords[_tokenId].endingTimestamp = endingTimestamp;

        emit Staked(_user, _tokenId, _timeframe);
    }

    function batchUnstake(
        uint256[] calldata tokenIds
    )
        external
        nonReentrant
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
        require(block.timestamp >= stakingRecords[_tokenId].endingTimestamp, "still locked");
        require(
            stakingRecords[_tokenId].tokenOwner == msg.sender,
            "Sender must have staked tokenId"
        );
        
        delete stakingRecords[_tokenId];
        numOfTokenStaked[_user]--;
        IERC721Enumerable(KCGAddress).safeTransferFrom(
            address(this),
            _user,
            _tokenId
        );

        emit Unstaked(_user, _tokenId);
    }

    function getStakingRecords(address _user) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](numOfTokenStaked[_user]);
        uint256[] memory expiries = new uint256[](numOfTokenStaked[_user]);
        uint256 counter = 0;
        for(uint i = 0; i < IERC721Enumerable(KCGAddress).totalSupply(); i++) {
            if (stakingRecords[i].tokenOwner == _user) {
                tokenIds[counter] = stakingRecords[i].tokenId;
                expiries[counter] = stakingRecords[i].endingTimestamp;
                counter++;
            }
        }
        return (tokenIds, expiries);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata data
    )
        public returns (bytes4)
    {
        return _ERC721_RECEIVED;
    }

    // MIGRATION ONLY.
    function setKCGNFTContract(address _address) public onlyOwner {
        KCGAddress = _address;
    }

    // EMERGENCY ONLY.
    function setEmergencyUnstakePaused(bool _setEmergencyUnstakePaused)
        public
        onlyOwner
    {
        emergencyUnstakePaused = _setEmergencyUnstakePaused;
    }

    function emergencyUnstake(uint256 _tokenId) external nonReentrant {
        require(!emergencyUnstakePaused, "public mint paused");
        require(
            stakingRecords[_tokenId].tokenOwner == msg.sender,
            "Sender must have staked tokenId"
        );
        _unstake(msg.sender, _tokenId);
        emit EmergencyUnstake(msg.sender, _tokenId);
    }

}