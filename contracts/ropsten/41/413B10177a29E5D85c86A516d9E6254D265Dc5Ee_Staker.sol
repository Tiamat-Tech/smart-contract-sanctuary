pragma solidity ^0.5.16;

import "openzeppelin-solidity/contracts/GSN/Context.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract Staker is Ownable {
    using SafeMath for uint256;
    using Address for address;
    
    IERC20 private f9token;
    IERC20 private shibatoken;
    mapping (address => mapping(address => uint256)) _tokenBalances;
    mapping (address => uint256) _unlockTime;
    mapping (address => bool) _isIDO;
    mapping (address => bool) _isF9Staked;
    mapping (address => uint8) _shibaTier;
    mapping (address => bool) _isShibaStaked;
    bool private halted;
    uint256 private shibaIndividualMaxStake = 499999;
    uint256 private shibaTotalMaxStake = 1000000000;
    uint256 private totalStakedShiba = 0;
    uint64[3] private shibaTiers = [9999, 49999, 99999];
    uint8[3] private shibaTiersStaked = [0, 0, 0];
    uint8[3] private shibaTiersMax = [100, 100, 100];

    event Stake(address indexed account, uint256 timestamp, uint256 value);
    event Unstake(address indexed account, uint256 timestamp, uint256 value);
    event Lock(address indexed account, uint256 timestamp, uint256 unlockTime, address locker);

    constructor(address _f9, address _shibatoken) public {
        f9token = IERC20(_f9);
        shibatoken = IERC20(_shibatoken);
    }

    function stakedBalance(IERC20 token, address account) external view returns (uint256) {
        return _tokenBalances[address(token)][account];
    }

    function unlockTime(address account) external view returns (uint256) {
        return _unlockTime[account];
    }

    function isIDO(address account) external view returns (bool) {
        return _isIDO[account];
    }

    function isF9Staked(address account) external view returns (bool) {
        return _isF9Staked[account];
    }

    function isShibaStaked(address account) external view returns (bool) {
        return _isShibaStaked[account];
    }

    function getShibaTiersStaked() external view returns (uint8[3] memory){
        return shibaTiersStaked;
    }

    function stake(IERC20 token, uint256 value) internal {
        token.transferFrom(_msgSender(), address(this), value);
        _tokenBalances[address(token)][_msgSender()] = _tokenBalances[address(token)][_msgSender()].add(value);
        emit Stake(_msgSender(), now, value);
    }

    function unstake(IERC20 token, uint256 value) internal {
        _tokenBalances[address(token)][_msgSender()] = _tokenBalances[address(token)][_msgSender()].sub(value,"Staker: insufficient staked balance");
        token.transfer(_msgSender(), value);
        emit Unstake(_msgSender(), now, value);
    }

    function shibaStake(uint8 tier) external notHalted {
        require (shibatoken.balanceOf(_msgSender()) >= shibaTiers[tier], "Staker: Stake amount exceeds wallet Shiba Inu balance");
        require (shibaTiersStaked[tier] < shibaTiersMax[tier], "Staker: Pool is full");
        require (_isShibaStaked[_msgSender()] == false, "Staker: User staked in other Shiba pool");
        require (_isF9Staked[_msgSender()] == false, "Staker: User staked in F9 pool");
        _isShibaStaked[_msgSender()] = true;
        _shibaTier[_msgSender()] = tier;
        shibaTiersStaked[tier] += 1;
        stake(shibatoken, shibaTiers[tier]);
    }

    function f9Stake(uint256 value) external notHalted {
        require(value > 0, "Staker: unstake value should be greater than 0");
        require (f9token.balanceOf(_msgSender()) >= value, "Staker: Stake amount exceeds wallet F9 balance");
        require (_isShibaStaked[_msgSender()] == false, "Staker: Wallet staked in Shiba pool");
        _isF9Staked[_msgSender()] == true;
        stake(f9token, value);
    }

    function shibaUnstake() external lockable {
        uint8 _tier = _shibaTier[_msgSender()];
        require(_tokenBalances[address(shibatoken)][_msgSender()] >= shibaTiers[_tier], 'Staker: insufficient staked Shiba balance');
        shibaTiersStaked[_tier] = shibaTiersStaked[_tier] -= 1;
        _isShibaStaked[_msgSender()] == false;
        unstake(shibatoken, shibaTiers[_tier]);
    } 

    function f9Unstake(uint256 value) external lockable {
        require(value > 0, "Staker: unstake value should be greater than 0");
        require(_tokenBalances[address(f9token)][_msgSender()] >= value, 'Staker: insufficient staked F9 balance');
        unstake(f9token, value);
        if (_tokenBalances[address(f9token)][_msgSender()] == 0){
            _isF9Staked[_msgSender()] = false;
        }
    }

    function updateShibaTiers(uint64 lowTier, uint64 middleTier, uint64 highTier) external onlyIDO {
        shibaTiers = [lowTier, middleTier, highTier];
    }

    function updateShibaTiersMax(uint8 lowTierMax, uint8 middleTierMax, uint8 highTierMax) external onlyOwner {
        shibaTiersMax = [lowTierMax, middleTierMax, highTierMax];
    }

    function getShibaTiers() external returns (uint64[3] memory) {
        return shibaTiers;
    }

    function getShibaTiersMax() external returns (uint8[3] memory) {
        return shibaTiersMax;
    }


    function lock(address user, uint256 unlockAt) external onlyIDO {
        require(unlockAt > now, "Staking Contract: unlock is in the past");
        if (_unlockTime[user] < unlockAt) {
            _unlockTime[user] = unlockAt;
            emit Lock(user,now,unlockAt,_msgSender());
        }
    }

    function halt(bool status) external onlyOwner {
        halted = status;
    }

    function addIDO(address account) external onlyOwner {
        require(account != address(0), "Staking Contract: cannot be zero address");
        _isIDO[account] = true;
    }

    modifier onlyIDO() {
        require(_isIDO[_msgSender()],"Staking Contract: only IDOs can lock");
        _;
    }

    modifier lockable() {
        require(_unlockTime[_msgSender()] <= now, "Staking Contract: account is locked");
        _;
    }

    modifier notHalted() {
        require(!halted, "Staking Contract: Deposits are paused");
        _;
    }
}