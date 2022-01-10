// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IToken
{
        function decimals() external view  returns (uint8);
        function allowance(address owner,address spender)  external view returns (uint256);
}

contract private2DDAO is AccessControl, ERC20
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
	IERC20 public token;

	address public Storage;

	uint public constant AmountMin = 500;
	uint public constant AmountMax = 1000;
	uint public AmountThis;
	uint public constant SoftCap = 100000;
	uint public constant HardCap = 197400;

//	address public Creator = _msgSender();

//	address public constant Usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
//	address public constant PayToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address public constant PayToken = 0x753f470F3a283A8e99e5dacf9dD0eDf7F64a9F80;
	
	event textLog(address,uint256,uint256);
	function decimals() public view virtual override returns (uint8) 
	{
		return 6;
	}
	function PayTokenDecimals()public view returns(uint8)
	{
		return IToken(PayToken).decimals();
	}

	constructor() ERC20("Private2 DDAO", "private2DDAO") 
	{

		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
//		Storage = address(this);
		Storage = _msgSender();

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
/*
	function Mint(uint amount)public virtual
	{
                _mint(_msgSender(), amount);
	}
*/
	function Buy(uint amount)public virtual
	{
		require(amount <= IToken(PayToken).allowance(_msgSender(),address(this)),"You need to be allowed to use tokens to pay for this contract [We are wait approve]");
		require(amount >= AmountMin,"The amount must be greater than AmountMin");
		require(amount <= AmountMax,"The amount must be less than AmountMax");
		require(AmountThis.add(amount) <= HardCap,"Hard cap reached");
		IERC20 ierc20Token = IERC20(PayToken);
//		ierc20Token.safeTransfer(_msgSender(), amount * 10 ** IToken(PayToken).decimals());
		ierc20Token.safeTransferFrom(_msgSender(),Storage,amount * 10 ** IToken(PayToken).decimals());
		_mint(_msgSender(), amount * 10 ** IToken(PayToken).decimals());		
		AmountThis = AmountThis.add(amount);
	}

	// FailStart functions 	
	function AdminGetCoin(uint256 amount) public onlyAdmin
	{
		payable(_msgSender()).transfer(amount);
	}

	function AdminGetToken(address tokenAddress, uint256 amount) public onlyAdmin 
	{
		IERC20 ierc20Token = IERC20(tokenAddress);
		ierc20Token.safeTransfer(_msgSender(), amount);
	}
	// End of failstart

	function StorageChange(address addr) public onlyAdmin 
	{
		Storage = addr;
	}

}