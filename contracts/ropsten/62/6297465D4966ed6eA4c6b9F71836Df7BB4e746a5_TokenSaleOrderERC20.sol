// SPDX-License-Identifier: UNLICENSED
// TokenSaleOrderERC20 v1.0.0 by Stakedex.io 2021

pragma solidity 0.8.0;

import "./IERC20.sol";
import "./EnumerableAddressSet.sol";
import "./TokenSaleFactory.sol";
import "./TokenSaleLib.sol";
import "./IUniswapV2Router02.sol";
import "./ITokenLock.sol";

contract TokenSaleOrderERC20
  {
   TokenSaleFactory _Factory;
   
   IERC20 public _LPToken;            // liquidity token required
   IERC20 public _rewardToken;        // reward token provided by posteBy
   IERC20 public _entranceFeeToken;   // token used for entrance fee
  
   address public _postedBy;       // who posted the order
   address public _devWallet;
   address public _uniRouter;
   address public _lockAddress;     // team.finance lock contract
   
   uint public _entranceFee;        // amount charged for staking entrance fee
   uint public _stakeFee;           // fee in LP % taken from stakers  
   uint public _numBlocks;          // end block for staking
   uint public _lastBlockCalc;      // last time balances were modified
   uint public _rewardsLeft;        // remaining reward balance for informational purposes
   uint public _rewardsPerBlock;    // total rewards per block (this is divided amongst participants)
   uint public _totalStake;         // total amount of LP being staked between all stakers
   uint public _minStake;           // minimum amount of stake
   uint public _rewardAmount;       // amount of reward when posted
   uint public _numBlocksLeft;      // amount of unrewarded blocks
  
   uint public _unlockTime;          // unix time in seconds
   uint public _liquidityPercent;    // percent of stake to add as liquidity
   bool private _initialized;
   bool public _isActive;            // contract is active
   bool public _featured;
   bool public _isDone;              // contract is completely done
   
   mapping(address => uint) public _stakeBalance;   // stake balances of stakers
   mapping(address => uint) public _rewardBalance;  // reward balances of stakers
   mapping(address => uint) public _enteredBlock;   // block at which this address entered. used to make sure nobody entered while going thrugh_Stakers list
  
   using EnumerableAddressSet for EnumerableAddressSet.AddressSet;
   EnumerableAddressSet.AddressSet _Stakers;
   
   function initialize(TokenSaleLib.OrderVars calldata vars) external
   {
     require(!_initialized);
     _initialized = true;

     require(vars.rewardToken != address(0) && vars.LPToken != address(0));
      
     _rewardToken = IERC20(vars.rewardToken);
     _LPToken = IERC20(vars.LPToken);
     _entranceFeeToken = IERC20(vars.entranceFeeToken);

     _stakeFee = vars.stakeFee;
     _postedBy = vars.postedBy;
     _numBlocks = vars.numBlocks;
     _numBlocksLeft = vars.numBlocks;
     _Factory = TokenSaleFactory(msg.sender);
     _devWallet = vars.devWallet;
     _minStake = vars.minStake;

     _unlockTime = vars.unlockTime;
     _liquidityPercent = vars. liquidityPercent;
     
     _uniRouter = vars.uniRouter;
     _lockAddress = vars.lockAddress;
     
     _featured = vars.featured;
     
     if(_minStake < 10000)
       _minStake = 10000;
     
     _rewardAmount = vars.rewardAmount;
   }

   function startOrder() public
   {
     // only factory can start this order
     require(msg.sender == address(_Factory));
     
     uint256 allowance = _rewardToken.allowance(msg.sender, address(this));
     require(allowance >= _rewardAmount);
    
     // factory should have paid us the reward purse
     require(_rewardToken.transferFrom(msg.sender, address(this), _rewardAmount));
    
     _rewardsLeft = _rewardAmount;
     _rewardsPerBlock = _rewardAmount / _numBlocks;
    
     _lastBlockCalc = block.number;
     _isActive = true; // order is ready to start as soon as we get our first staker    
   }
  
   // update all balances when a balance has been modified
   // this makes the user staking/withdrawing pay for the updates gas
   function updateBalances() public returns(bool)
   {
     // this is important because it is dealing with users funds
     // users can enter staking while we are iterating _Stakers list
     // we have keep track of when they entered so everyone gets paid correctly
    
     if(!_isActive)
       return(true);
     
     require(_numBlocksLeft > 0);
     
     uint len = _Stakers.length();
    
     if(len > 0) // dont have to do any of this is there are no stakers
       {
	 uint blockNum = block.number;
	 uint pendingRewards = getPendingRewards();
	 uint pendingBlocks = getPendingBlocks();
	 bool calcs = false;
	 
	 // calculate and modify all balances
	 for(uint i=0;i<len;i++)
	   {
	     address staker = _Stakers.at(i);
	     if(_enteredBlock[staker] < blockNum) // prevent counting of stakers who just entered while we are iterating the list
	       {
		 uint scale = 100000;
		 uint scaledbalance = (_stakeBalance[staker] * scale);
		      
		 if(scaledbalance > _totalStake) // avoid division error
		   {
		     uint num = scaledbalance / _totalStake * pendingRewards;
      
		     if(num > scale) // avoid division error
		       {
			 _rewardBalance[staker] = _rewardBalance[staker] + (num/scale);
			 calcs = true;
		       }
		   }
	       }
	   }
       
	 if(calcs) // only do this if we actually added to any balances
	   {
	     _rewardsLeft = _rewardsLeft - pendingRewards;
	     _numBlocksLeft = _numBlocksLeft - pendingBlocks;
	   }
       }

     bool closed = false;
     if( _numBlocksLeft == 0)
       {
	 _Factory.closeOrder(address(this));
	 iclose();
	 closed = true;
       }
     
     _lastBlockCalc = block.number;
     return(closed);
   }

   // stake
   function stake(uint amount) public
   {
     require(_isActive);

     if(updateBalances())
       return;
   
     require(amount >= _minStake);
     require(_entranceFeeToken.allowance(msg.sender, address(this)) >= amount);

     // stakers pay staking fee
     uint stakefee = amount * _stakeFee / 10000; // 10 is .01%
     uint stakeAmount = amount - stakefee;
     
     // send staker fee to devwallet
     require(_entranceFeeToken.transferFrom(msg.sender, _devWallet, stakefee) == true);

     // send rest to this
     require(_entranceFeeToken.transferFrom(msg.sender, address(this), stakeAmount));
     
     uint lpAmount = stakeAmount * _liquidityPercent / 10000; // 10 is .01%     
     uint payAmount = amount - lpAmount;

     // postedBy gets remaining entranceFeeToken
     require(_entranceFeeToken.transferFrom(msg.sender, _postedBy, payAmount));
     
     // obtain lpAmount of LP tokens
     uint lpAdded = addLiquidity(lpAmount);
     
     // LP Fees are taken from locked liquidity
     uint LPfeeAmount = lpAdded * _stakeFee / 10000; // 10 is .01% - fee to send to devwallet
     uint lockAmount = lpAdded - LPfeeAmount; // amount of liquidity to lock

     // send LP fee to dev wallet
     require(_LPToken.transfer(_devWallet, LPfeeAmount) == true);
     //require(_LPToken.transferFrom(address(this), _devWallet, LPfeeAmount) == true);

     // send lockAmount of LP tokens to locker
     ITokenLock lock = ITokenLock(_lockAddress);
     require(_LPToken.approve(_lockAddress, lockAmount));
     lock.lockTokens(address(_LPToken), lockAmount, _unlockTime);
     
     // add to our stakers
     _stakeBalance[msg.sender] = _stakeBalance[msg.sender] + stakeAmount; // add just in case they have already staked before
     _totalStake = _totalStake + stakeAmount;
     
     if(!_Stakers.contains(msg.sender)) // new staker
       {
	 _Stakers.add(msg.sender);
	 _enteredBlock[msg.sender] = block.number;
       }
   }

   function addLiquidity(uint amount) internal returns(uint)
   {
     IUniswapV2Router02 uni = IUniswapV2Router02(_uniRouter);
     uint ramount = _rewardToken.balanceOf(address(this));
     
     _entranceFeeToken.approve(_uniRouter, 0);
     _entranceFeeToken.approve(_uniRouter, amount);
     
     _rewardToken.approve(address(_uniRouter), 0);
     _rewardToken.approve(address(_uniRouter), ramount);
     
     // use exact amount of payment token amount and send as many rewardtokens as needed
     (,,uint liquidity) = uni.addLiquidity(address(_entranceFeeToken), address(_rewardToken), amount, ramount, amount, 1, address(this), block.timestamp);
     return(liquidity);
   }

   // collect uncollected rewards
   function collectRewards() public 
   {
     // always update balances before we change anything
     if(updateBalances())
       return;
   
     require(_rewardBalance[msg.sender] > 0);   
   
     require(_rewardToken.transfer(msg.sender, _rewardBalance[msg.sender]));
     _rewardBalance[msg.sender] = 0;
   }
   
   function isStaker(address addr) public view returns(bool)
   {
     return(_Stakers.contains(addr));
   }   
   
   function getPendingRewards() public view returns (uint)
   {
     if(_Stakers.length() == 0) // all balances should already be correct
       return(0); 
     return(_rewardsPerBlock * getPendingBlocks());
   }

   function getPendingBlocks() public view returns(uint)
   {
     if(_Stakers.length() == 0 )
       return(0);
     if((block.number - _lastBlockCalc) >= _numBlocksLeft) // contract is done
       return _numBlocksLeft; // prevent neg number
     
     else return(block.number - _lastBlockCalc);
   }

   function withdrawUnlockedLP() internal
   {
     if(block.timestamp >= _unlockTime)
       {
	 ITokenLock lock = ITokenLock(_lockAddress);
	 uint256[] memory lockIDs = lock.getDepositsByWithdrawalAddress(address(this));
	 
	 // withdraw all the tokens
	 for(uint i=0;i<lockIDs.length;i++)
	   {
	     lock.withdrawTokens(lockIDs[i]);
	   }
       }
   }

   // allow poster to closed this order after unlockTime
   function closeUnlockedOrder() public
   {
     require(_isDone == false && _isActive == false);
     require(msg.sender == _postedBy);
     require(block.timestamp >= _unlockTime);
     
     _isDone = true;     
     // notify factory we are closing...  again
     _Factory.closeOrder(address(this));
     
     withdrawUnlockedLP();
     
     // shouldn't be any other tokens left in contract but just in case
     // there are send them all to postedBy
     uint rewardAmount = _rewardToken.balanceOf(address(this));
     uint lpAmount = _LPToken.balanceOf(address(this));
     uint eAmount = _entranceFeeToken.balanceOf(address(this));
     
     // send all remaining tokens back to poster (if any)
     if(rewardAmount > 0)
       _rewardToken.transfer(_postedBy, rewardAmount);
     if(lpAmount > 0)
       _LPToken.transfer(_postedBy, lpAmount);
     if(eAmount > 0)
       _entranceFeeToken.transfer(_postedBy, eAmount);
     
   }
   
   // close order
   function iclose() internal
   {
     require(_isActive);
       _isActive = false;
     
     // notify factory we are closing
     _Factory.closeOrder(address(this));
     
     for(uint i=0;i<_Stakers.length();i++)
       {
	 // remaining rewards to stakers
	 if(_rewardBalance[_Stakers.at(i)] > 0)
	   _rewardToken.transfer(_Stakers.at(i), _rewardBalance[_Stakers.at(i)]);
       }     
   }

   function getContractBalances() public view returns(uint, uint, uint)
   {
     return(_entranceFeeToken.balanceOf(address(this)), _rewardToken.balanceOf(address(this)), _LPToken.balanceOf(address(this)) );
   }
   
   function getStakers() public view returns(TokenSaleLib.stakeOut[] memory)
   {
     uint len = _Stakers.length();
     TokenSaleLib.stakeOut[] memory out = new TokenSaleLib.stakeOut[](len);
    
     for(uint i=0;i<len;i++)
       {
	 out[i].staker = _Stakers.at(i);
	 out[i].stake =  _stakeBalance[_Stakers.at(i)];
       }
     return out;
   }

   function getInfo(address sender) public view returns(TokenSaleLib.stakeInfo memory)
   {
     TokenSaleLib.stakeInfo memory out;
     ITokenLock lock = ITokenLock(_lockAddress);
     
     out.LPToken = address(_LPToken);          
     out.rewardToken = address(_rewardToken);
     out.entranceFeeToken = address(_entranceFeeToken);
     out.postedBy =  address(_postedBy);
     out.addr = address(this);
     
     out.stakeFee =  _stakeFee;              // fee in LP % taken from stakers  
     out.numBlocks = _numBlocks;             // end block for staking
     out.minStake = _minStake;               // minimum amount of stake
     out.rewardAmount = _rewardAmount;       // amount of reward when posted
     out.isActive = _isActive;
     out.isDone = _isDone;
     out.featured = _featured;
     out.unlockTime = _unlockTime;
     out.liquidityPercent = _liquidityPercent;
     
     out.lastBlockCalc = _lastBlockCalc;
     out.myStake = _stakeBalance[sender];
     out.myUnclaimed = _rewardBalance[sender];
     out.totalStake = _totalStake;               // total amount of LP being staked between all stakers
     out.numBlocksLeft = _numBlocksLeft;
     out.lockedTokens = lock.getTokenBalanceByAddress(address(_LPToken), address(this));
     out.stakers = getStakers();
     return(out);
   }
  }