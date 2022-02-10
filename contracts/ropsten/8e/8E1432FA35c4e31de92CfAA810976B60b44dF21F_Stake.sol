// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC20.sol";

contract stakeContract is ERC20, Ownable {
    uint256 private  _totalSupply = 50000000 * 10 ** 8;
    address private  minter ;

    constructor (string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, _totalSupply);
    }
    
    function burn(uint256 amount) external  {
        _burn(msg.sender, amount);
    }

    function mint(address reciever, uint256 amount) external  {
        require(msg.sender == minter, "Unauthorized");
         _mint(reciever, amount);
    }

    function set_minter( address reciever) external onlyOwner {
        minter = reciever;
    }
}

contract Stake is  Ownable{
    using SafeMath for uint256;
    
    stakeContract private rewardToken;

    IERC20 private token;
    
    uint256 private startsAt;

    uint256 private endsAt;
    
    bool private initialized = false;
    
    uint256 private stakerCountERC = 0;

    uint256 private totalStakeERC = 0;
       
    uint256 private rewardSupply = 100000;
    
    struct stakeERC {
        bool isExist;
        uint256 stake;
        uint256 stakeTime;
        uint256 harvested;
    }
    
    mapping (address => stakeERC) private stakerERC;
   
    event StakedERC(address _staker, uint256 _amount , uint256 _time);
   
    event UnStakedERC(address _staker, uint256 _amount , uint256 _time);
   
    event HarvestedERC(address _staker, uint256 _amount , uint256 _time);
    
    function initialize(address _token) public onlyOwner returns(bool){
        require(!initialized);
		require(_token != address(0));
		token = stakeContract(_token);
		initialized = true;
		return true;
	}

    function setStartsAt(uint256 _time) onlyOwner public returns (bool){
        startsAt = _time;
        return true;
    }
    
    function setEndsAt(uint256 _time) onlyOwner public  returns (bool){
        endsAt = _time;
        return true;
    }
    
    function stake_ERC(uint256 _amount ) public returns (bool) { 
        require (_amount > 0, "Invalid amount");
        require (token.allowance(msg.sender, address(this)) >= _amount, "Token not approved");
        require (!stakerERC[msg.sender].isExist, "You already staked");
        token.transferFrom(msg.sender, address(this), _amount);
        stakeERC memory stakerinfo;
        stakerCountERC++;

        stakerinfo = stakeERC({
            isExist: true,
            stake: _amount,
            stakeTime: block.timestamp,
            harvested: 0
        });
        totalStakeERC += _amount;
        
        stakerERC[msg.sender] = stakerinfo;
        emit StakedERC(msg.sender, _amount ,block.timestamp);
        return true;
    }

    function unstake_ERC() public returns (bool) {
        require (stakerERC[msg.sender].isExist, "You are not staked");
        if(getCurrentReward_ERC(msg.sender) > 0){
            _harvest_ERC(msg.sender); 
        }
        token.transfer(msg.sender, stakerERC[msg.sender].stake);
        emit UnStakedERC(msg.sender, stakerERC[msg.sender].stake ,block.timestamp);
        totalStakeERC -= stakerERC[msg.sender].stake;
        stakerCountERC--;
        stakerERC[msg.sender].isExist = false;
        stakerERC[msg.sender].stake = 0;
        stakerERC[msg.sender].stakeTime = 0;
        stakerERC[msg.sender].harvested = 0;
        return true;
    }

    function harvest_ERC() public returns (bool) {
        _harvest_ERC(msg.sender);
        return true;
    }

    function _harvest_ERC(address _user) internal {
        require(getCurrentReward_ERC(_user) > 0, "Nothing to harvest");
        uint256 harvestAmount = getCurrentReward_ERC(_user);
        rewardToken.mint(_user, harvestAmount);
        stakerERC[_user].harvested += harvestAmount;
        emit HarvestedERC(_user, harvestAmount ,block.timestamp);
    }

    function getTotalReward_ERC(address _user) public view returns (uint256) {
        if(stakerERC[_user].isExist){
        return uint256(block.timestamp).sub(stakerERC[_user].stakeTime).mul(stakerERC[_user].stake).mul(rewardSupply).div(totalStakeERC).div(1 days);
        }else{
            return 0;
        }
    }
    
    function getCurrentReward_ERC(address _user) public view returns (uint256) {
        if(stakerERC[_user].isExist){
            return (getTotalReward_ERC(_user)).sub(stakerERC[_user].harvested);
        }else{
            return 0;
        }
    }
    
    function getTotalStakeERC() public view  returns (uint256){
       return totalStakeERC;
    }
    
    function getStakerERC(address _userAddress) public view returns (bool , uint256 , uint256 , uint256){
        return  (stakerERC[_userAddress].isExist, stakerERC[_userAddress].stake , stakerERC[_userAddress].stakeTime , stakerERC[_userAddress].harvested );
    }
    
    function getStartTime() public view returns (uint) {
        return startsAt;
    }

    function getEndTime() public view returns (uint) {
        return endsAt;
    }
 
}