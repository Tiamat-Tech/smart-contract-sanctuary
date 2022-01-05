// SPDX-License-Identifier: MIT
/* ======================================================== DEFI HUNTERS DAO ====================================================================
                                                     https://defihuntersdao.club/
------------------------------------------------------------ January 2021 -----------------------------------------------------------------------
###     ###  ###    ###  ####    ### ########## ########  #######      #####          ####         #####      #####  ########    #####     ##### 
###    #### ####   ####  #####   ### ########## ########  #########  ########        #####       ########   ######## ########  ########  ########
###    #### ####   ####  #####   ### #########  ########  ###  ####  #######         ######    #########  #########  ########  #######   #######  
###    #### ####   ####  ######  ###    ###     ###       ###   ### ####             ######    ####       ####       ###      ####      ####     
########### ####   ####  ####### ###    ###     ########  #########  ######         ### ####  ####       ####        ########  ######    ###### 
########### ####   ####  ### #######    ###     ########  ########    #######       ###  ###  ####       ####        ########   #######   #######
###    #### ####   ####  ###  ######    ###     ###       ###  ####      ####      ########## ####       ####        ###           ####      ####
###    ####  ###   ####  ###   #####    ###     ###       ###  ####       ###      ##########  ####       ####       ###            ###       ### 
###    ####  #########   ###   #####    ###     ########  ###   ###  ########     ####    ###   ########   ########  ########  ########  ########
###    ####   #######    ###    ####    ###     ########  ###   ############      ####    ####   ########   ######## ######## ########  ########

                                         #########            ####                         
                                            ###      #######  #### ####  #######  ######## 
                                            ###     ######### ######### ######### #########
                                            ###    ####   ### #######   ###   ### ####  ###
                                            ###    ###    ### #######   ######### ####  ###
                                            ###    ####   ### ########  ###       ####  ###
                                            ###     ######### #### #### ######### ####  ###
                                            ###      #######  ####  #### ######## ####  ###
---------------------------------------------------------------------------------------------------------------------------------------------- */
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";

//import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
//@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


interface IToken 
{
	function decimals() external view  returns (uint8);
	function allowance(address owner,address spender)  external view returns (uint256);
}

contract HAT is ERC721, Ownable, Pausable
{
	using SafeERC20 for IERC20;
	address public PayToken;
	uint256 public TicketCount = 0;

	struct params 
	{
		uint8 num;
		string name;
		uint256 interval;
		uint256 cost;
		bool disposable;
	}
	mapping(uint8 => params) public Params;

	constructor() ERC721("Hunters Access Tiket", "HAT")
	{
		// USDC Polygon
		//PayToken = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
		// USDC Ropsten
		//PayToken = 0x753f470F3a283A8e99e5dacf9dD0eDf7F64a9F80;
		PayTokenChange(0x753f470F3a283A8e99e5dacf9dD0eDf7F64a9F80);
		ParamAdd(1,'Test Access 7 Days',7 days,100,true);
		ParamAdd(2,'Access 30 Days',30 days,500,false);
		ParamAdd(3,'Access 365 Days',365 days,2000,false);
		ParamAdd(4,'Unlimit Access',36500 days,10000,false);
	}

	function pause(bool val)public onlyOwner
	{
		require(val != paused(),'Contract already has you new status');

		if(val)_pause();
		else
		_unpause();
	}
	function PayTokenChange(address addr)public onlyOwner
	{
		PayToken = addr;
	}

	function ParamAdd(uint8 Number, string memory Name, uint256 TimeInterval, uint256 Cost, bool Disposable)public onlyOwner
	{
		Params[Number] = params(Number,Name,TimeInterval,Cost,Disposable);
	}
	function AdminGetCoin(uint256 amount) public onlyOwner
	{
		payable(_msgSender()).transfer(amount);
	}
	function AdminGetToken(address tokenAddress, uint256 amount) public onlyOwner
	{
		IERC20 ierc20Token = IERC20(tokenAddress);
		ierc20Token.safeTransfer(_msgSender(), amount);
	}
	function PayTokenBalance()public view returns(uint256)
	{
		return IERC20(PayToken).balanceOf(address(this));
	}
	function PayTokenDecimals()public view returns(uint8)
	{
		return IToken(PayToken).decimals();
	}
	function Buy(address to, uint8 param_id,uint256 time)public
	{
		require(Params[param_id].num == param_id,"This param_id not exists");

		uint256 amount = Params[param_id].cost * 10 ** IToken(PayToken).decimals();
		require(amount <= IToken(PayToken).allowance(_msgSender(),address(this)),"You need to be allowed to use tokens to pay for this contract [We are wait approve]");
		
		IERC20(PayToken).safeTransferFrom(_msgSender(),address(this),amount);

		_safeMint(to, TicketCount, "");
		TicketCount++;
	}
}