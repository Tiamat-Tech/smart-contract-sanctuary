// SPDX-License-Identifier: MIT
/* ======================================================= DEFI HUNTERS DAO =========================================================
	                                           https://defihuntersdao.club/
------------------------------------------------------------ Feb 2021 ---------------------------------------------------------------
 NNNNNNNNL     NNNNNNNNL       .NNNN.      .NNNNNNN.        .JNNNNNN (NNNNNNNNNN    JNNNL     (NN)  .NNNN NNN
 NNNNNNNNNN.   NNNNNNNNNN.     JNNNN)     JNNNNNNNNNL       NNNNNNNF (NNNNNNNNNN   .NNNNN     (NN)  NNNN  NNN
 NNN    4NNN   NNN    4NNN     NNNNNN    (NNN`   `NNN)     (NNF          NNN       (NNNNN)    (NN) NNNF        .__ .___       ___..__
 NNN     NNN)  NNN     NNN)   (NN)4NN)   NNN)     (NNN     (NNN_         NNN       NNN`NNN    (NN)NNNF    NNN  (NNNNNNNN)   JNNNNNNNN
 NNN     4NN)  NNN     4NN)   NNN (NNN   NNN`     `NNN      4NNNNN.      NNN      (NN) NNN)   (NNNNNN.    NNN  (NNNF"NNNN  (NNNF"NNNN
 NNN     JNN)  NNN     JNN)  (NNF  NNN)  NNN       NNN       "NNNNNN     NNN      NNN` (NNN   (NNNNNNN    NNN  (NNF   NNN  NNN)   NNN
 NNN     NNN)  NNN     NNN)  JNNNNNNNNL  NNN)     (NNN          4NNN)    NNN     .NNNNNNNNN.  (NNN NNNL   NNN  (NN)   NNN  NNN    NNN
 NNN    JNNN   NNN    JNNN  .NNNNNNNNNN  4NNN     NNNF           (NN)    NNN     JNNNNNNNNN)  (NN) `NNN)  NNN  (NN)   NNN  NNN)  .NNN
 NNN___NNNN`   NNN___NNNN`  (NNF    NNN)  NNNNL_JNNNN      (NL__JNNN)    NNN     NNN`   (NNN  (NN)  (NNN) NNN  (NN)   NNN  (NNNNNNNNN
 NNNNNNNNN`    NNNNNNNNN`   NNN`    (NNN   4NNNNNNNF       (NNNNNNN)     NNN    (NNF     NNN) (NN)   (NNN.NNN  (NN)   NNN   `NNNNNNNN
 """"""`       """"""`      """      """     """""          `""""`              `""`     `""`             """  `""`   """        .NNN
                                                                                                                            NNNNNNNN)
                                                                                                                            NNNNNNN`
================================================================================================================================ */
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IToken
{
        function approve(address spender,uint256 amount)external;
        function allowance(address owner,address spender)external view returns(uint256);
        function balanceOf(address addr)external view returns(uint256);
        function decimals() external view  returns (uint8);
        function name() external view  returns (string memory);
        function symbol() external view  returns (string memory);
        function totalSupply() external view  returns (uint256);
}

contract DDAOStaking01 is AccessControl
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
//	IERC20 public token;

	address public owner = _msgSender();

	struct info
	{
	    address 	addr;
	    uint48 	time;
	    uint256 	amount;
	    uint256 	stale;
	}
	

	uint48 public StakeTime  = 1 hours;
	uint8  constant stake_steps = 5;
	mapping (address => info) public Stakers;
	uint16 constant koef = 1000;

	// DDAO TOken
	// testnet
	 address public TokenAddr = 0xF870b9C48C2B9757696c25988426e2A0941334B5;
	// mainnet
	//address public TokenAddr = 0x90F3edc7D5298918F7BB51694134b07356F7d0C7;

	event debug(uint256 v1,uint256 amount);
	event debug2(uint48);
	event debug3(address addr,uint256 stale,uint48 time);
	event eStake(address addr, uint256 amount,  uint48 time, uint256 now_amount, uint256 stale);
	event eUnStake(address addr, uint256 amount,  uint48 time, uint256 now_amount, uint256 stale);

	constructor() 
	{
	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
	_setupRole(DEFAULT_ADMIN_ROLE, 0x208b02f98d36983982eA9c0cdC6B3208e0f198A3);
	//_setupRole(DEFAULT_ADMIN_ROLE, 0x80C01D52e55e5e870C43652891fb44D1810b28A2);

//	Stake(0xa5B32272f2FE16d402Fe6Da4EDfF84cD6f8e4AA0, 3000000000000000000000);

	}

	// Start: Admin functions
	event adminModify(string txt, address addr);
	modifier onlyAdmin() 
	{
		require(IsAdmin(_msgSender()), "Access for Admin's only");
		_;
	}

	function IsAdmin(address account) public virtual view returns (bool)
	{
		return hasRole(DEFAULT_ADMIN_ROLE, account);
	}
	function AdminAdd(address account) public virtual onlyAdmin
	{
		require(!IsAdmin(account),'Account already ADMIN');
		grantRole(DEFAULT_ADMIN_ROLE, account);
		emit adminModify('Admin added',account);
	}
	function AdminDel(address account) public virtual onlyAdmin
	{
		require(IsAdmin(account),'Account not ADMIN');
		require(_msgSender()!=account,'You can`t remove yourself');
		revokeRole(DEFAULT_ADMIN_ROLE, account);
		emit adminModify('Admin deleted',account);
	}
	// End: Admin functions

	function TokenAddrSet(address addr)public virtual onlyAdmin
	{
		TokenAddr = addr;
	}

	function AdminGetCoin(uint256 amount) public onlyAdmin
	{
		payable(_msgSender()).transfer(amount);
	}

	function AdminGetToken(address tokenAddress, uint256 amount) public onlyAdmin 
	{
		IERC20 ierc20Token = IERC20(tokenAddress);
		ierc20Token.safeTransfer(_msgSender(), amount);
	}
	function StakeTimeChange(uint48 time)public onlyAdmin
	{
	    StakeTime = time;
	}

	function balanceOf(address addr)public view returns(uint256 balance)
	{
//		balance = claimers[addr];
//		balance = Stakers[addr].amount *
		balance = Stakers[addr].stale + StakeCalculate(addr,0);
	}
        function TokenBalance() public view returns(uint256)
        {
                IERC20 ierc20Token = IERC20(TokenAddr);
                return ierc20Token.balanceOf(address(this));
        }

	// owner ddao and his friend
	function Stake(address addr,uint256 amount)public
	{	
	    require(amount <= IERC20(TokenAddr).balanceOf(_msgSender()),"Not enough tokens to receive");
	    require(IERC20(TokenAddr).allowance(_msgSender(),address(this)) >= amount,"You need to be allowed to use tokens to pay for this contract [We are wait approve]");
	    uint256 v1 = amount.div(10**IToken(TokenAddr).decimals());
	    v1 = v1.mul(10**IToken(TokenAddr).decimals());
	    emit debug(v1,amount);
	    require(amount == v1,"Amount must be integer only.");

	    if(addr == address(0))addr = _msgSender();

	    if(Stakers[addr].time == 0)
	    {
		Stakers[addr].time 	= uint48(block.timestamp);
		Stakers[addr].addr 	= addr;
		Stakers[addr].amount 	= amount;
		Stakers[addr].stale 	= 0;
		//emit debug2(0);
	    }
	    else
	    {
		uint256 stale = StakeCalculate(addr,uint48(block.timestamp));
		Stakers[addr].time 	= uint48(block.timestamp);
		Stakers[addr].amount 	= amount - stale + Stakers[addr].amount;
		Stakers[addr].stale 	= stale;
		//emit debug2(Stakers[addr].time);
		//emit debug3(addr,StakeCalculate(addr,Stakers[addr].time),Stakers[addr].time);
		//emit debug3(addr,StakeCalculate(addr,0),0);
	    }
	    emit eStake(addr, amount, Stakers[addr].time, Stakers[addr].amount, Stakers[addr].stale);
	    
	}
	function StakeCalculate(address addr,uint48 time)public view returns(uint256 stale)
	{
	    if(time == 0)time = uint48(block.timestamp);

	    uint48 	interval;
	    uint256 	delta_amount;
	    uint48 	delta_time;
	    uint256 	part;
	    interval 	= StakeTime * stake_steps;
	    delta_amount = Stakers[addr].amount - Stakers[addr].stale;
	    delta_time 	= time - Stakers[addr].time; 
	    part = delta_time * koef / interval;
	    if(part > koef)part = koef;
	    stale = Stakers[addr].amount * part / koef;
	}
	//only owner of ddao
	function Unstake(uint256 amount)public
	{
	    address addr = _msgSender();
	    uint256 all = Stakers[addr].amount + Stakers[addr].stale;
	    require(amount <= all,'You have requested more tokens than you have in the stake');
	    if(Stakers[addr].stale == 0)
	    {
		Stakers[addr].amount = Stakers[addr].amount.sub(amount);
	    }
	    else
	    {
		if(amount >= Stakers[addr].amount)
		{
		    amount = amount.sub(Stakers[addr].amount);
		    Stakers[addr].amount = 0;

		    Stakers[addr].stale = Stakers[addr].stale.sub(amount);
		}
		else
		{
		    Stakers[addr].amount = Stakers[addr].amount.sub(amount);
		}
		
	    }
	    Stakers[addr].time = uint48(block.timestamp);
	    emit eUnStake(addr, amount, Stakers[addr].time, Stakers[addr].amount, Stakers[addr].stale);
	}
	function BlockTime()public view returns(uint256)
	{
	    return block.timestamp;
	}
}