// SPDX-License-Identifier: UNLICENSED
// StakeOrderFactory by Stakedex.io 2021

pragma solidity 0.8.0;

import "./IERC20.sol";
import "./EnumerableAddressSet.sol";
//import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./TokenSaleOrderERC20.sol";
import "./TokenSaleOrderLib.sol";

contract TokenSaleOrderFactory
{
  IERC20 public _homeToken;  
  address public _devWallet;
  IUniswapV2Router02 _uniRouter;
  
  uint public _featureFee;  
  bool private _initialized;
  bool public _isActive;
  
  using EnumerableAddressSet for EnumerableAddressSet.AddressSet;
  EnumerableAddressSet.AddressSet _openOrders;
  EnumerableAddressSet.AddressSet _lockedOrders;
  EnumerableAddressSet.AddressSet _closedOrders;

  uint public  _stakingFee; // divide by 10000 (10 is .1%, or .001)
  
  mapping(address => bool) public _owners;  
  mapping(address => bool) public _featured;
  
  function initialize(uint stakeFee, uint featureFee, address uniRouter) public
  {
    require(!_initialized);
    _initialized = true;
    _owners[msg.sender] = true;
    _devWallet = msg.sender;
    _stakingFee = stakeFee;
    _featureFee = featureFee;
    _uniRouter = IUniswapV2Router02(uniRouter);
  }

  function deployERC20Staking(address rewardToken, uint rewardAmount, uint numBlocks, uint stakingFee, uint entranceFee, address entranceFeeToken, address premiumToken, uint premiumAmount, bool featured, uint lockPercent, uint unlockBlock) public returns(address)
  {
    require(_isActive);
    TokenSaleOrderLib.OrderVars memory vars;
    
    // the public
    vars.rewardToken = rewardToken;
    vars.rewardAmount = rewardAmount;
    vars.postedBy = msg.sender;
    vars.numBlocks = numBlocks;
    vars.stakeFee = _stakingFee;
    vars.entranceFee  = entranceFee;
    vars.entranceFeeToken = entranceFeeToken;

    // TODO replace this with poster pricing tiers
    vars.premiumToken = address(0);
    vars.premiumAmount = 0;
    
    vars.devWallet = _devWallet;
    
    vars.lockPercent = lockPercent;
    vars.unlockBlock = unlockBlock;
    
    vars.uniRouter = address(_uniRouter);
    
    if (address(_homeToken) != address(0))
      vars.featured = featured;

    // owners can set nore options
    if(_owners[msg.sender])
      {
	vars.stakeFee = stakingFee;
	vars.premiumToken = premiumToken;
	vars.premiumAmount = premiumAmount;
      }
    return(deploy(vars));
  }

  function uniswapPair(address tokenA, address tokenB) internal view returns(address)
  {
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    IUniswapV2Factory uniFactory = IUniswapV2Factory(_uniRouter.factory());

    address paddress = uniFactory.getPair(token0,token1);
    require(paddress != address(0), "Liquidity pair does not exist"); // make sure pair exists
     return(paddress);
  }

  function deploy(TokenSaleOrderLib.OrderVars memory vars) internal returns(address)
  {
    require(vars.rewardAmount >= vars.numBlocks); 
    vars.LPToken = uniswapPair(vars.entranceFeeToken, vars.rewardToken);
    
    if(!_owners[vars.postedBy] && vars.featured) // featureFee is paid with homeToken
      {
	uint256 allowance = _homeToken.allowance(vars.postedBy, address(this));
	require(allowance >= _featureFee && _homeToken.transferFrom(vars.postedBy, _devWallet, _featureFee));
      }
    
    IERC20 token = IERC20(vars.rewardToken);

    TokenSaleOrderERC20 tokenSaleOrder = new TokenSaleOrderERC20();
    require(token.allowance(vars.postedBy, address(this)) >= vars.rewardAmount &&
	    token.transferFrom(vars.postedBy, address(this), vars.rewardAmount) &&
	    token.approve(address(tokenSaleOrder), vars.rewardAmount));
    
    _openOrders.add(address(tokenSaleOrder));
    _featured[address(tokenSaleOrder)] = vars.featured;
    tokenSaleOrder.initialize(vars);
    tokenSaleOrder.startOrder();
    return(address(tokenSaleOrder));
  }
  
  function setUniRouter(address addr) public
  {
    require(_owners[msg.sender]);
    _uniRouter = IUniswapV2Router02(addr);

    uint len = _openOrders.length();
    for(uint i=0;i<len;i++)
      TokenSaleOrderERC20(_openOrders.at(i)).setUniRouter(addr);
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
  
  function getLockedOrders() public view returns(address[] memory)
  {
    return(addressSetToArray(_lockedOrders));
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
    TokenSaleOrderERC20 order = TokenSaleOrderERC20(addr);
    if(addr == msg.sender) // contract closing itself
      {
	if(block.number < order._unlockBlock())
	  {
	    // order is closed but still locked
	    if(_openOrders.contains(addr))
	      {
		_lockedOrders.add(addr);
		_openOrders.remove(addr);
	      }
	  }
	else
	  {
	    // order is not locked
	    if(_openOrders.contains(addr))
	      _openOrders.remove(addr);
	    if(_lockedOrders.contains(addr))
	      _lockedOrders.remove(addr);
	    _closedOrders.add(addr);
	  }
      }

    // dev is emergency closing the order. This can happen to scam tokens, fraudulent listings, etc.
    // owners of stakedex cannot cancel their own order. This is to comfort users that stakedex cannot rug a token sale.
    if(_owners[msg.sender])
      {
	if(!_owners[order._postedBy()])  // owners of Stakedex cannot cancel official stakedex orders
	  {
	    if(_openOrders.contains(addr))
	      _openOrders.remove(addr);
	    if(_lockedOrders.contains(addr))
	      _lockedOrders.remove(addr);
	    _closedOrders.add(addr);
	    order.close();
	  }
      }
  }

  // owner functions
  function setActive(bool a) public
  {
    require(_owners[msg.sender]);
      _isActive = a;
  }

  // stakedex token for featured fee
  function setHomeToken(address a) public
  {
    require(_owners[msg.sender]);
    _homeToken = IERC20(a);
  }
  
  function setFeatured(address addr, bool a) public
  {
    TokenSaleOrderERC20 order = TokenSaleOrderERC20(addr);
    address postedBy = order._postedBy();
    if(_owners[msg.sender]) // owners pay no fees
      _featured[addr] = a;
    else if(address(_homeToken) != address(0) && msg.sender == postedBy && a == true) // featureFee is paid with homeToken
      {
	uint256 allowance = _homeToken.allowance(postedBy, address(this));
	require(allowance >= _featureFee && _homeToken.transferFrom(postedBy, _devWallet, _featureFee));
	_featured[addr] = true;
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
    _stakingFee = percent;
  }

  function setDevWallet(address addr) public
  {
    require(_owners[msg.sender]);
    _devWallet = addr;
  }
}