// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Hunter01 is AccessControl, ERC20
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
	IERC20 public token;

	uint public constant AmountMin = 10000;
	uint public constant SoftCap = 1*10**6;
	uint public constant HardCap = 2*10**6;

	address public Creator = _msgSender();

	address public constant Usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
//	address public constant Usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address public constant Usdc = 0x753f470F3a283A8e99e5dacf9dD0eDf7F64a9F80;
	
	event textLog(address,uint256,uint256);
	function decimals() public view virtual override returns (uint8) 
	{
		return 6;
	}

	constructor() ERC20("Hunter PreSale 01", "HUNTER01") 
	{

	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

                //uint256 initialSupply = 10 * 10**decimals();
                //_mint(_msgSender(), initialSupply);
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

	function Mint(uint amount)public virtual
	{
                _mint(_msgSender(), amount);
	}
	function Buy(uint amount)public virtual
	{
		IERC20 ierc20Token = IERC20(Usdc);
//		ierc20Token.safeTransfer(_msgSender(), amount);
		ierc20Token.safeTransferFrom(_msgSender(),address(this),amount);
		_mint(_msgSender(), amount);		
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

}