// SPDX-License-Identifier: UNLICENSED
// StakeOrderFactory by Stakedex.io 2021

pragma solidity 0.8.0;

import "./IERC20.sol";
import "./EnumerableAddressSet.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./LPStakeOrderERC20.sol";
import "./StakeOrderLib.sol";
import "./UniUtils.sol";

contract StakeOrderFactory
{
  IUniswapV2Pair _PairETHUSD;          // used to fetch current eth price
  address public _devWallet;
  uint public _featureFee;             // in USDC paid in ETH 
  uint public _postingFee;             // in USDC paid in ETH
  bool private _initialized;
  bool public _isActive;
  
  using EnumerableAddressSet for EnumerableAddressSet.AddressSet;
  EnumerableAddressSet.AddressSet _openOrders;
  EnumerableAddressSet.AddressSet _closedOrders;

  uint public _stakingFeeLPERC20; // divide by 10000 (10 is .1%, or .001)
  
  mapping(address => bool) public _owners;  
  mapping(address => bool) public _partners;
  
  function initialize(uint stakeFee_, uint featureFee_, uint postingFee_, address ethusd_) public
  {
    require(!_initialized);
    _initialized = true;
    _owners[msg.sender] = true;
    _devWallet = msg.sender;
    _stakingFeeLPERC20 = stakeFee_;
    _featureFee = featureFee_; // in usdc paid in eth
    _postingFee = postingFee_; // in usdc pain in eth (per block)
    
    // ETH/USDC Mainnet
    _PairETHUSD = IUniswapV2Pair(ethusd_);
  }

  function deployERC20Staking(address LPToken_, address rewardToken_, uint rewardAmount_, uint numBlocks_, uint stakingFee_, uint entranceFee_, uint minStake_, bool featured_, uint startTime_) public payable returns(address)
  {
    require(_isActive);
    StakeOrderLib.OrderVars memory vars;
    
    // the public
    vars.LPToken = LPToken_;
    vars.rewardToken = rewardToken_;
    vars.rewardAmount = rewardAmount_;
    vars.postedBy = msg.sender;
    vars.numBlocks = numBlocks_;
    vars.stakeFee = _stakingFeeLPERC20;
    vars.entranceFee  = 0;
    vars.minStake = minStake_;
    vars.devWallet = _devWallet;
    vars.featured = featured_;
    vars.startTime = startTime_;

    // owners can set nore options
    if(_owners[msg.sender])
      {
	vars.stakeFee = stakingFee_;
	vars.entranceFee = entranceFee_;
      }
	    
    return(deploy(vars, msg.value));
  }

  function deploy(StakeOrderLib.OrderVars memory vars, uint paid) internal returns(address)
  {
    require(vars.rewardAmount >= vars.numBlocks);
    
    if(!_owners[vars.postedBy] && !_partners[vars.postedBy]) // owners and partners pay no fees
      {
	uint256 amountDue = 0;

	if(vars.featured)
	  amountDue += UniUtils.getAmountForPrice(_PairETHUSD, _featureFee);
	amountDue += UniUtils.getAmountForPrice(_PairETHUSD, _postingFee*vars.numBlocks);
	
	if(amountDue > 0)
	  {
	    require(paid >= amountDue);  // allow postedBy to pay more than amount due because of fluctuating USD/ETH prices
	  }
     }
      
    IERC20 token = IERC20(vars.rewardToken);
    IUniswapV2Pair lptoken = IUniswapV2Pair(vars.LPToken);

    require(lptoken.MINIMUM_LIQUIDITY() > 0, "invalid LP token");
        
    LPStakeOrderERC20 stakeOrder = new LPStakeOrderERC20();
    require(token.allowance(vars.postedBy, address(this)) >= vars.rewardAmount &&
	    token.transferFrom(vars.postedBy, address(this), vars.rewardAmount) &&
	    token.approve(address(stakeOrder), vars.rewardAmount));
    
    _openOrders.add(address(stakeOrder));
    
    stakeOrder.initialize(vars);
    stakeOrder.startOrder();
    return(address(stakeOrder));
  }
  
  function setPartner(address addr, bool b) public
  {
    require(_owners[msg.sender]);
    _partners[addr] = b;
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
 
  function closeOrder(address addr) public
  {
    // devs and order poster can delist the order
    if(_openOrders.contains(addr) && (addr == msg.sender || _owners[msg.sender])) 
      {
	_closedOrders.add(addr);
	_openOrders.remove(addr);
	
	// ** BETA: This command will be removed after beta **
	// safety mechanism in case contract locks funds due to bugs
	// allows factory to shutdown the contract and pay out all tokens
	LPStakeOrderERC20 order = LPStakeOrderERC20(addr);
	order.close();
      }
  }

  // withdraw eth in this contract to owner
  function withdraw() public
  {
    require(_owners[msg.sender]);
    payable(_devWallet).transfer(address(this).balance);
  }

  // lock/unlock this contract
  function setActive(bool a) public
  {
    require(_owners[msg.sender]);
      _isActive = a;
  }

  // set the fee for featured orders
  function setFeatureFee(uint a) public
  {
    require(_owners[msg.sender]);
      _featureFee = a;
  }

  // add/remove owner
  function setOwner(address n, bool a) public
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

  // set fee payout wallet
  function setDevWallet(address addr) public
  {
    require(_owners[msg.sender]);
    _devWallet = addr;
  }

  // convert USDC amount to ETH @ current ETH price in USD
  function usdToEth(uint amount) public view returns(uint)
  {
    return(UniUtils.getAmountForPrice(_PairETHUSD, amount));
  }
}