/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

pragma solidity ^0.5.0;

library Math {

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function average(uint256 a, uint256 b) internal pure returns (uint256) {

        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

library SafeMath {
   
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
   
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
   
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }


    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Context {

    constructor () internal { }
   
    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; 
        return msg.data;
    }
}


contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }


    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }


    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
   
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    
    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}


library Address {

    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
     
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }

    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
    }


    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}


library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");


        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
         
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


contract IRewardDistributionRecipient is Ownable {
    address public rewardDistribution;
    address public developerWallet;

    function notifyRewardAmount(uint256 reward) external;

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, "Caller is not reward distribution");
        _;
    }

    function setRewardDistributionAndDevWallet(address _rewardDistribution, address _developerWallet)
        external
        onlyOwner
    {
        rewardDistribution = _rewardDistribution;
        developerWallet = _developerWallet ;
    }
}


contract LPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
     
     // staking --[  MVP ]-- tokens to get --[ MVP ]-- tokens as reward
    IERC20 public MVP_Pool = IERC20(0x65fC94d99Cb301C5630c485D312e6Ff5EDdE13d0);

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        MVP_Pool.safeTransferFrom(msg.sender, address(this), amount);

    }

    function withdraw(uint256 amount) public {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        MVP_Pool.safeTransfer(msg.sender, amount);
    }
}


contract MVPPool is LPTokenWrapper, IRewardDistributionRecipient {
    IERC20 public mvp = IERC20(0x65fC94d99Cb301C5630c485D312e6Ff5EDdE13d0);
    uint256 public constant DURATION = 6048000;      // <!-- 10 WEEKS -->

    uint256 public starttime = 1604500200;       // <!-- Nov-4-2020 @ 2:30pm (UTC) -->
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public rewardInterval = 172800;        //----| 48hr = 172800 |----| 72hr = 259200 |
    uint256 public withdrawInterval = 604800;      // <!-- 7 DAYS -->

    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public lastTimeStaked;
    mapping(address => uint256) public lastTimeRewarded;


    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event DevRewardPaid(address indexed user, uint256 reward);

    modifier checkStart(){
        require(block.timestamp >= starttime,"MVP Pool not started yet.");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }


    function calculateFees(uint256 amount) internal pure returns (uint256) {
        return amount.mul(50).div(1000);
            
    }

    //---------| 172800 == 48 hours |--------| 900 == 10 minutes|-------------------
    function setRewardInterval(uint256  _rewardInterval) external onlyOwner {
           rewardInterval = _rewardInterval;   
    }
    //---------| 604800 == 7 days |----------| 900 == 10 minutes|-------------------
    function setWithdrawInterval(uint256 _withdrawInterval) external onlyOwner {
           withdrawInterval = _withdrawInterval;    
    }

    function getRewardInterval() public view returns (uint256){
       
        return rewardInterval;
    }
 
    function getWithdrawInterval() public view returns (uint256){
       
        return withdrawInterval;
   }

    function calculateFourPercent(uint256 amount) internal pure returns (uint256) {
        return amount.mul(40).div(1000);
            
    }
  
   function getRewardAmount() public onlyOwner {
    
        mvp.safeTransfer(msg.sender, mvp.balanceOf(address(this)));

   }

    function tokensLeft() public view returns (uint256){
       
        return mvp.balanceOf(address(this));
   }

    function stake(uint256 amount) public updateReward(msg.sender) checkStart {
        require(developerWallet != address(0), "Developer wallet is not set");
        require(amount > 0, "Cannot stake 0");
        super.stake(amount);
        lastTimeStaked[msg.sender] = block.timestamp;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) checkStart {
        require(amount > 0, "Cannot withdraw 0");
        uint256 leftTime = block.timestamp.sub(lastTimeStaked[msg.sender]);
        
        require(leftTime >= withdrawInterval , "Can remove stake once 7 days is over");
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);

    }
     // withdraw stake and get rewards at once
    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }


    // reward can be withdrawn after 48 hour 
    function getReward() public updateReward(msg.sender) checkStart {
        uint256 reward = earned(msg.sender);
        uint256 trueReward = reward;

        uint256 leftTimeReward = block.timestamp.sub(lastTimeRewarded[msg.sender]);
        require(leftTimeReward >= rewardInterval , "Can claim reward once 48 hour is completed");

        if (reward > 0) {
            rewards[msg.sender] = 0; 
            uint256 fee = calculateFees(trueReward);
            uint256 rewardMain = trueReward.sub(fee);
            uint256 rewardDev = calculateFourPercent(trueReward);

            mvp.safeTransfer(msg.sender, rewardMain);
            mvp.safeTransfer(developerWallet, rewardDev);

            lastTimeRewarded[msg.sender] = block.timestamp; 

            emit RewardPaid(msg.sender, rewardMain);
            emit DevRewardPaid(msg.sender, rewardDev);
        }
    }

    function notifyRewardAmount(uint256 reward)
        external
        onlyRewardDistribution
        updateReward(address(0))
    {
        if (block.timestamp > starttime) {
          if (block.timestamp >= periodFinish) {
              rewardRate = reward.div(DURATION);
          } else {
              uint256 remaining = periodFinish.sub(block.timestamp);
              uint256 leftover = remaining.mul(rewardRate);
              rewardRate = reward.add(leftover).div(DURATION);
          }
          lastUpdateTime = block.timestamp;
          periodFinish = block.timestamp.add(DURATION);
          emit RewardAdded(reward);
        } else {
          rewardRate = reward.div(DURATION);
          lastUpdateTime = starttime;
          periodFinish = starttime.add(DURATION);
          emit RewardAdded(reward);
        }
    }
}