pragma solidity ^0.6.6;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract Ownable {
  address public owner;
  address public waitNewOwner;
    
  event transferOwner(address newOwner);
  
  constructor() public{
      owner = msg.sender;
  }
  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(owner == msg.sender);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   * and safe new contract new owner will be accept owner
   */
  function transferOwnership(address newOwner) onlyOwner public {
    if (newOwner != address(0)) {
      waitNewOwner = newOwner;
    }
  }
  /**
   * this function accept when transfer to new owner and new owner will be accept owner for safe contract free owner
   */
   
  function acceptOwnership() public {
      if(waitNewOwner == msg.sender) {
          owner = msg.sender;
          emit transferOwner(msg.sender);
      }else{
          revert();
      }
  }

}

contract LockupLikepoint is Ownable {

	//created by prapat polchan

    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeERC20 for IERC20;   

    enum statusWithdraw {
        INACTIVE,
        ACTIVE
    }
   
    
    struct timeLock {
        IERC20 token;
        uint256 expire;
        uint256 block;
        uint256 start;
        uint256 amount;
        statusWithdraw isWithdraw;
    }



    mapping (uint256 => uint256) public option;
    
    IERC20 public likepoint;
    uint256 public maxOption = 4;
    mapping (address => mapping(uint256 => timeLock)) public timelockhold;
    uint256 public balanceToken;
    mapping (uint256 => uint256) public optionBalance;
    



    event DepositToken(address sender, uint256 amount, uint256 expire, uint256 option, uint256 totalLock);
    event WithdrawToken(address sender, uint256 amount, uint256 option, uint256 totalLock);
    event ChangeOptionTime(uint256 option, uint256 time);
    function setInit() onlyOwner public {
    	option[0] = 30 days;
    	option[1] = 90 days;
    	option[2] = 180 days;
    	option[3] = 365 days;
    }


    function changeOptionTime(uint256 _option, uint256 time) onlyOwner public {
    	option[_option] = time;
    	emit ChangeOptionTime(_option, time);
    }
    function depositLockup(uint256 amount, uint256 _option) public returns (bool) {
		require (_option < maxOption, "exceed options");   	    	
    	uint256 expireTime = option[_option];

    	timeLock memory user = timelockhold[msg.sender][_option];
    	user.token = likepoint;
    	user.expire = now.add(expireTime);
    	user.block = block.number;
    	user.start = now;
    	user.amount = user.amount.add(amount);
    	user.isWithdraw = statusWithdraw.INACTIVE;
    	timelockhold[msg.sender][_option] = user;
    	uint256 totalLock = timelockhold[msg.sender][_option].amount;
    	optionBalance[_option] = optionBalance[_option].add(amount);

    	likepoint.safeTransferFrom(address(msg.sender), address(this), amount);
    	balanceToken = balanceToken.add(amount);
 		emit DepositToken(msg.sender, amount, expireTime, _option, totalLock);
 		return true;

    }

    function withdrawLockup(uint256 amount, uint256 _option) public  returns (bool){
        timeLock memory user = timelockhold[msg.sender][_option];
        require(now >= user.expire);
        require(amount <= user.amount);

        user.amount = user.amount.sub(amount);
        timelockhold[msg.sender][_option] = user;      
        balanceToken= balanceToken.sub(amount);

 		optionBalance[_option] = optionBalance[_option].sub(amount);
        likepoint.safeTransfer(address(msg.sender), amount);
        emit WithdrawToken(msg.sender, amount ,_option, optionBalance[_option]);

        return true;
        
    }

    function getBalance() public view returns (uint256) {
    	return balanceToken;
    }
    function getOptionBalance(uint256 option) public view returns (uint256) {
    	return optionBalance[option];
    }
    function getOptionLength() public view returns (uint256) {
    	return maxOption;
    }



}