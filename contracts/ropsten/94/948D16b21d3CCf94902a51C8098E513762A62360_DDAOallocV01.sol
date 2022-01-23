// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

contract DDAOallocV01 is AccessControl, Ownable
{
        using SafeMath for uint256;
        using SafeERC20 for IERC20;

//	IERC20 public Token;
	address public TokenAddr;

//	event textLog(address owber,address,uint256);
	event Approval(address owner, address spender, uint256 value);


	struct info
	{
		address addr;
		uint8 decimals;
		string name;
		string symbol;
		uint256 totalSupply;
	}
        constructor()
        {
        	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		// DevUSDC
		TokenAddr = 0x753f470F3a283A8e99e5dacf9dD0eDf7F64a9F80;

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
	function TokenAllowance(address addr)public view returns(uint256 value)
	{
		value = IToken(TokenAddr).allowance(addr,address(this));
	}
	function TokenInfo()public view returns(info memory val)
	{
		val.addr = TokenAddr;
		val.decimals = IToken(TokenAddr).decimals();
		val.name = IToken(TokenAddr).name();
		val.symbol = IToken(TokenAddr).symbol();
		val.totalSupply = IToken(TokenAddr).totalSupply();
	}

}