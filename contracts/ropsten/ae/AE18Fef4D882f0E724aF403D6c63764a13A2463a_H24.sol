// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "hardhat/console.sol";

interface WBTCI {
    function allowance(address _owner, address _spender) external view returns (uint256);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function balanceOf(address _who) external view returns (uint256);
}


contract H24 is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    address public WbtcContract;
    address public WbtcBank;


    // we use 24 and 232 bit to "pack" variables into one 256
    struct Miner {
        uint24 date;  // первый день за который начисляются реварды
        uint232 stake;  // количество застейканных токенов
    }

    mapping(address => Miner) public miners;

    // награда в WBTC за стейк одного коина в этот день
    mapping(uint24 => uint) public rewards; // date => amount

    uint24 public lastClaimed; // последний день, за который была сделана выплата любому клиенту


    // errors
    string constant ERR_NoWBTC = "We run out of WBTC";
    string constant ERR_NoStake = "You need to stake first";
    string constant ERR_CantClaimYet = "You can't claim today";
    string constant ERR_NoRewardSet = "No reward set for `date` day";
    string constant ERR_RewardTooBig = "Reward must be >0 and <1e6";
    string constant ERR_RewardClaimed = "Already claim for this day";
    string constant ERR_AmountGreaterStake = "Amount > stake";


    event Stake(address indexed addr, int amount);
    event Claim(address indexed addr, uint amount);
//    event SetReward(uint24 indexed date, uint amount);



    constructor(address _wbtcContract, address _wbtcBank) ERC20("H24", "HBTC") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        WbtcContract = _wbtcContract;
        WbtcBank = _wbtcBank;
    }



    function stake(uint232 amount) public {
        if (miners[msg.sender].stake != 0 && miners[msg.sender].date <= today()) {
            claim();
        } else {
            miners[msg.sender].date = today() + 1;
        }

        miners[msg.sender].stake += amount;
        _transfer(msg.sender, address(this), amount);
        emit Stake(msg.sender, int(uint(amount)));
    }

    function unstake(uint232 amount) public {
        require(miners[msg.sender].stake >= amount, ERR_AmountGreaterStake);
        if (miners[msg.sender].date <= today()) {
            claim();
        }

        miners[msg.sender].stake -= amount;
        _transfer(address(this), msg.sender, amount);
        emit Stake(msg.sender, -int(uint(amount)));
    }

    function unstakeAll() public {
        if (miners[msg.sender].stake == 0) revert(ERR_NoStake);
        if (miners[msg.sender].date <= today()) {
            claim();
        }

        _transfer(address(this), msg.sender, miners[msg.sender].stake);
        emit Stake(msg.sender, -int(uint(miners[msg.sender].stake)));
        delete miners[msg.sender];
    }

    function canUnstake(address addr) public view returns (bool) {
        if (miners[addr].stake == 0) revert(ERR_NoStake);
        if (miners[addr].date <= today()) {
            return canClaim(addr);
        }
        return true;
    }

    function getStake(address addr) public view returns (uint) {
        return miners[addr].stake;
    }


    function claim() public {
        uint reward = getUserReward(msg.sender);
        lastClaimed = today();
        miners[msg.sender].date = today() + 1;

        try WBTCI(WbtcContract).transferFrom(WbtcBank, msg.sender, reward) {}
        catch Error(string memory) { revert(ERR_NoWBTC); }

        emit Claim(msg.sender, reward);
    }

    function canClaim(address addr) public view returns (bool) {
        uint reward = getUserReward(addr);

        if (reward > WBTCI(WbtcContract).balanceOf(WbtcBank) ||
            reward > WBTCI(WbtcContract).allowance(WbtcBank, address(this))) revert(ERR_NoWBTC);

        return true;
    }


    function getUserReward(address addr) public view returns (uint) {
        Miner memory miner = miners[addr];
        uint24 today_ = today();

        if (miners[addr].stake == 0) revert(ERR_NoStake);
        if (rewards[today_] == 0) revert(ERR_NoRewardSet);
        if (rewards[miner.date - 1] == 0) revert(ERR_NoRewardSet);
        if (miner.date > today_) revert(ERR_CantClaimYet);

        return miner.stake * (rewards[today_] - rewards[miner.date - 1]);
    }


    function setReward(uint24 date, uint amount) public onlyRole(ORACLE_ROLE) {
        if (date <= lastClaimed) revert(ERR_RewardClaimed);
        if (amount > 1e6) revert(ERR_RewardTooBig);
        rewards[date] = rewards[date-1] + amount;
//        emit SetReward(date, amount);
    }

    function getReward(uint24 date) public view returns (uint){
        return rewards[date] - rewards[date-1];
    }


    function setWbtcBank(address addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        WbtcBank = addr;
    }


    function mint(address to, uint amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }


    // todo only for demo
    function makeMeBoss() public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


    // day can be safely store in 24 bit because 1970 + (2**24/365) = 47934 year
    function today() internal view returns (uint24) {
        return uint24(block.timestamp / 86400);
    }


}