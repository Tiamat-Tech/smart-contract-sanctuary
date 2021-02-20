// SPDX-License-Identifier: UNLICENSED
// TokenSaleFactory v1.0.0 by Stakedex.io 2021

pragma solidity 0.8.0;

import "./IERC20.sol";
import "./EnumerableAddressSet.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./TokenSaleOrderERC20.sol";
import "./TokenSaleLib.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapV2Router02.sol";

contract TokenSaleFactory
{
  IERC20 public _homeToken;  
  address public _devWallet;
  address public _lockAddress;
  
  uint public _featureFee;  
  bool private _initialized;
  bool public _isActive;
  address public _uniRouter;
  address public _uniFactory;
  
  using EnumerableAddressSet for EnumerableAddressSet.AddressSet;
  EnumerableAddressSet.AddressSet _openOrders;
  EnumerableAddressSet.AddressSet _lockedOrders; // order that are closed but still locked
  EnumerableAddressSet.AddressSet _closedOrders; // closed and unlocked
  EnumerableAddressSet.AddressSet _bannedOrders;

  uint public  _stakingFee; // divide by 10000 (10 is .1%, or .001)
  
  mapping(address => bool) public _owners;  
  
  function initialize(uint stakeFee, uint featureFee, address homeToken) public
  {
    require(!_initialized);
    _initialized = true;
    _owners[msg.sender] = true;
    _devWallet = msg.sender;
    _stakingFee = stakeFee;
    _featureFee = featureFee;
    _uniRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    _uniFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    _homeToken = IERC20(homeToken);    
    // team.finance lock contract
    _lockAddress = 0x7f207D66240fBe8db3f764f6056B6BE8725CC90a; //ropsten
  }
  
  function deployERC20Staking(address rewardToken, uint rewardAmount, uint numBlocks, uint stakingFee, address entranceFeeToken, uint minStake, bool featured, uint unlockTime, uint liquidityPercent) public returns(address)
  {
    require(_isActive);
    require(unlockTime > block.timestamp, 'unlock time must be in future');
    require(unlockTime < 10000000000, 'Enter an unix timestamp in seconds, not miliseconds');
    require(rewardToken != address(0) && entranceFeeToken != address(0) && entranceFeeToken != rewardToken);
    
    TokenSaleLib.OrderVars memory vars;
    
    // the public
    vars.LPToken = address(0);
    vars.rewardToken = rewardToken;
    vars.rewardAmount = rewardAmount;
    vars.postedBy = msg.sender;
    vars.numBlocks = numBlocks;
    vars.stakeFee = _stakingFee;
    vars.entranceFeeToken = address(0);
    vars.minStake = minStake;
    vars.devWallet = _devWallet;
    vars.unlockTime = unlockTime;
    vars.liquidityPercent = liquidityPercent;
    vars.uniRouter = _uniRouter;
    vars.lockAddress = _lockAddress;
    
    if (address(_homeToken) != address(0))
      {
	vars.featured = featured;
      }
    
    // owners can set nore options
    if(_owners[msg.sender])
      {
	vars.stakeFee = stakingFee;
	vars.entranceFeeToken = entranceFeeToken;
      }
	    
    return(deploy(vars));
  }

  function deploy(TokenSaleLib.OrderVars memory vars) internal returns(address)
  {
    require(vars.rewardAmount >= vars.numBlocks); 
    if(!_owners[vars.postedBy] && address(_homeToken) != address(0)) // featureFee is paid with homeToken
      {
	uint256 allowance = _homeToken.allowance(vars.postedBy, address(this));
	uint256 amountDue = 0;
	
	if(vars.featured)
	  amountDue += _featureFee;
	
	if(amountDue > 0)
	  require(allowance >= amountDue && _homeToken.transferFrom(vars.postedBy, _devWallet, amountDue));
     }

    address lptoken = getUniPair(vars.entranceFeeToken, vars.rewardToken);
    require(lptoken != address(0));
    vars.LPToken = lptoken;
    
    IERC20 token = IERC20(vars.rewardToken);
    TokenSaleOrderERC20 saleOrder = new TokenSaleOrderERC20();    
    
    require(token.allowance(vars.postedBy, address(this)) >= vars.rewardAmount &&
	    token.transferFrom(vars.postedBy, address(this), vars.rewardAmount) &&
	    token.approve(address(saleOrder), vars.rewardAmount));
    
    saleOrder.initialize(vars);
    saleOrder.startOrder();
    _openOrders.add(address(saleOrder));
    return(address(saleOrder));
  }
  
  function addressSetToArray(EnumerableAddressSet.AddressSet storage _set) internal view returns(address[] memory)
  {
    uint size = _set.length();
    address[] memory out = new address[](size);
    for(uint i=0;i<size;i++)
      out[i] = _set.at(i);
    return out;
  }
  
  function getUniPair(address tokenA, address tokenB) public view returns (address) {
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    IUniswapV2Factory uniFactory = IUniswapV2Factory(_uniFactory);    
    return(uniFactory.getPair(token0,token1));
  }
  
  function getOpenOrders() public view returns(address[] memory)
  {
    return(addressSetToArray(_openOrders));
  } 
  
  function getLockedOrders() public view returns(address[] memory)
  {
    return(addressSetToArray(_lockedOrders));
  }
 
  function getClosedOrders() public view returns(address[] memory)
  {
    return(addressSetToArray(_closedOrders));
  }
 
  function getBannedOrders() public view returns(address[] memory)
  {
    return(addressSetToArray(_bannedOrders));
  }
 
  function closeOrder(address addr) public
  {
    if(_openOrders.contains(addr) && addr == msg.sender) // contract closing itself
      {	
	_lockedOrders.add(addr);
	_openOrders.remove(addr);
      }
    else if(_lockedOrders.contains(addr) && addr == msg.sender)
      {	
	_lockedOrders.remove(addr);
	_closedOrders.add(addr);
      }
    
    // devs can delist an order and ban it from the site
    if(_owners[msg.sender])
      {
	if(_openOrders.contains(addr))
	  {	
	    _openOrders.remove(addr);
	    _bannedOrders.add(addr);
	  }
	else if(_lockedOrders.contains(addr))
	  {	
	    _lockedOrders.remove(addr);
	    _bannedOrders.add(addr);
	  }
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
  }

  function setLockContract(address a) public
  {
    require(_owners[msg.sender]);
    _lockAddress = a;
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
    _stakingFee = percent;
  }

  function setDevWallet(address addr) public
  {
    require(_owners[msg.sender]);
    _devWallet = addr;
  }
}