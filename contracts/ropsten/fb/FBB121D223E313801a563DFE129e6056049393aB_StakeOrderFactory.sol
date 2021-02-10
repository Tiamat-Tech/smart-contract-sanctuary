// SPDX-License-Identifier: UNLICENSED
// StakeOrderFactory by Stakedex.io 2021

pragma solidity 0.8.0;

import "./IERC20.sol";
import "./EnumerableAddressSet.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./LPStakeOrderERC20.sol";
import "./StakeOrderLib.sol";

contract StakeOrderFactory
{
  IERC20 public _homeToken;  
  address public _devWallet;
  uint public _featureFee;  
  bool private _initialized;
  bool public _isActive;
  
  using EnumerableAddressSet for EnumerableAddressSet.AddressSet;
  EnumerableAddressSet.AddressSet _openOrders;
  EnumerableAddressSet.AddressSet _closedOrders;

  uint public  _stakingFeeLPERC20; // divide by 10000 (10 is .1%, or .001)
  
  mapping(address => bool) public _owners;  
  mapping(address => bool) public _featured;
  mapping(uint => uint) public _tiers;
  mapping(uint => uint) public _tierFees; // all fees in _homeToken
  
  function initialize(uint stakeFee, uint featureFee) public
  {
    require(!_initialized);
    _initialized = true;
    _owners[msg.sender] = true;
    _devWallet = msg.sender;
    _stakingFeeLPERC20 = stakeFee;
    _featureFee = featureFee;
    _tiers[0] = 0;
    _tiers[1] = 50000000000000000000;
    _tiers[2] = 100000000000000000000;
    _tiers[3] = 500000000000000000000;
    _tiers[4] = 2500000000000000000000;
    _tiers[5] = 5000000000000000000000;
  }
  
  function deployERC20Staking(address LPToken, address rewardToken, uint rewardAmount, uint numBlocks, uint stakingFee, uint entranceFee, address entranceFeeToken, address premiumToken, uint premiumAmount, uint minStake, bool featured, uint tier) public returns(address)
  {
    require(_isActive);
    StakeOrderLib.OrderVars memory vars;
    
    // the public
    vars.LPToken = LPToken;
    vars.rewardToken = rewardToken;
    vars.rewardAmount = rewardAmount;
    vars.postedBy = msg.sender;
    vars.numBlocks = numBlocks;
    vars.stakeFee = _stakingFeeLPERC20;
    vars.entranceFee  = 0;
    vars.entranceFeeToken = address(0);
    vars.premiumAmount = 0;
    vars.minStake = minStake;
    vars.devWallet = _devWallet;
    
    if (address(_homeToken) != address(0))
      {
	vars.premiumToken = address(_homeToken);
	vars.tier = tier;
	vars.featured = featured;
      }
    
    // owners can set nore options
    if(_owners[msg.sender])
      {
	vars.stakeFee = stakingFee;
	vars.entranceFee = entranceFee;
	vars.entranceFeeToken = entranceFeeToken;
	vars.premiumToken = premiumToken;
	vars.premiumAmount = premiumAmount;
      }
	    
    return(deploy(vars));
  }

  function deploy(StakeOrderLib.OrderVars memory vars) internal returns(address)
  {
    require(vars.rewardAmount >= vars.numBlocks); 
    if(!_owners[vars.postedBy] && address(_homeToken) != address(0)) // featureFee is paid with homeToken
      {
	uint256 allowance = _homeToken.allowance(vars.postedBy, address(this));
	uint256 amountDue = 0;
	if(vars.featured)
	  amountDue += _featureFee;
	
	amountDue += _tierFees[vars.tier];
	
	if(amountDue > 0)
	  require(allowance >= amountDue && _homeToken.transferFrom(vars.postedBy, _devWallet, amountDue));
     }
    
    vars.premiumAmount = _tiers[vars.tier];
    
    IERC20 token = IERC20(vars.rewardToken);
    IUniswapV2Pair lptoken = IUniswapV2Pair(vars.LPToken);
    
    require(lptoken.MINIMUM_LIQUIDITY() > 0, "invalid LP token");
        
    LPStakeOrderERC20 stakeOrder = new LPStakeOrderERC20();
    require(token.allowance(vars.postedBy, address(this)) >= vars.rewardAmount &&
	    token.transferFrom(vars.postedBy, address(this), vars.rewardAmount) &&
	    token.approve(address(stakeOrder), vars.rewardAmount));
    
    _openOrders.add(address(stakeOrder));
    _featured[address(stakeOrder)] = vars.featured;
    stakeOrder.initialize(vars);
    stakeOrder.startOrder();
    return(address(stakeOrder));
  }
  
  function setTier(uint tier, uint amount) public
  {
    require(_owners[msg.sender]);
    _tiers[tier] = amount;
  }
  
  function setTierFee(uint tier, uint amount) public
  {
    require(_owners[msg.sender]);
    _tierFees[tier] = amount;
  }
  
  function addressSetToArray(EnumerableAddressSet.AddressSet storage _set) internal view returns(address[] memory)
  {
    uint size = _set.length();
    address[] memory out = new address[](size);
    for(uint i=0;i<size;i++)
      out[i] = _set.at(i);
    return out;
  }
  
  function getOpenOrders() public view returns(address[] memory)
  {
    return(addressSetToArray(_openOrders));
  } 
  
  function getClosedOrders() public view returns(address[] memory)
  {
    return(addressSetToArray(_closedOrders));
  }

  function isFeatured(address addr) public view returns(bool)
  {
    return(_featured[addr]);
  }
  
  function closeOrder(address addr) public
  {
    if(_openOrders.contains(addr) && (addr == msg.sender || _owners[msg.sender])) // owners or the contract itself
      {
	_closedOrders.add(addr);
	_openOrders.remove(addr);
      }

    // if contract is not closing itself we need to initiate close command
    if(_owners[msg.sender])
      {
	LPStakeOrderERC20 order = LPStakeOrderERC20(addr);
	order.close();
      }
  }

  // owner functions
  function setActive(bool a) public
  {
    require(_owners[msg.sender]);
      _isActive = a;
  }

  // stakedex token for featured / premium fees
  function setHomeToken(address a) public
  {
    require(_owners[msg.sender]);
    _homeToken = IERC20(a);
    _tierFees[0] = 5000000000000000000000;
    _tierFees[1] = 2500000000000000000000;
    _tierFees[2] = 500000000000000000000;
    _tierFees[3] = 100000000000000000000;
    _tierFees[4] = 50000000000000000000;
    _tierFees[5] = 0; // tier 5 orders are free

  }
  
  function setFeatured(address addr, bool a) public
  {
    if(_owners[msg.sender])
      {
	_featured[addr] = a;
      }
    else if(address(_homeToken) != address(0))
      {
	LPStakeOrderERC20 order = LPStakeOrderERC20(addr);
	if(msg.sender == order._postedBy() && a == true) // featureFee is paid with homeToken
	  {
	    uint256 allowance = _homeToken.allowance(order._postedBy(), address(this));
	    require(allowance >= _featureFee && _homeToken.transferFrom(order._postedBy(), _devWallet, _featureFee));
	    _featured[addr] = true;
	  }
      } 
  }
  
  function setFeatureFee(uint a) public
  {
    require(_owners[msg.sender]);
      _featureFee = a;
  }
  
  function setController(address n, bool a) public
  {
    require(_owners[msg.sender]);
    _owners[n] = a;
  }

  // set amount stakers pay in LP
  function setStakingFee(uint percent) public
  {
    require(_owners[msg.sender]);
    _stakingFeeLPERC20 = percent;
  }

  function setDevWallet(address addr) public
  {
    require(_owners[msg.sender]);
    _devWallet = addr;
  }
}