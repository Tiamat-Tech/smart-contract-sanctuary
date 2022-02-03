// SPDX-License-Identifier: MIT
/* =============================================================================== DEFI HUNTERS DAO ===============================================================================
                                                                            https://defihuntersdao.club/
------------------------------------------------------------------------------------ February 2021 --------------------------------------------------------------------------------
########       #######         #####         ####         ###########                                           ###      ###                            ##                               
##########    ##########       #####      ##########      ###########                                           ####    ####                           ####                              
###########   ###########     #######    ############     ###########                                           ####    ####                    ####   ####                              
####    ####  ####    ####    #######    ####    ####         ###       #####    #######   ######### ####        ###   ####    #####    ###### ####### ####  ########      ########      
####    ####  ####    ####    ### ###   ####      ####        ###     #########  ########  ###############       ####  ####  ######### ####### ####### ####  #########   ##########      
####     ###  ####     ###   #### ####  ####      ####        ###     ###   ###       ###  ####  ####  ####      ####  ###   ###   ### ####     #####  ####  ####  ####  ####  ####      
####     ###  ####     ###   #########  ####      ####        ###    ##########  ########  ###   ####  ####       ########  ########## ######   ####   ####  ###   #### ####   ####      
####    ####  ####    ####  ########### ####      ####        ###    ########## #########  ###   ####  ####       #######   ##########  ####### ####   ####  ###   #### ####   ####      
####   #####  ####   #####  ###########  ####    ####         ###     ###       ###   ###  ###   ####  ####        ######    ###           #### ####   ####  ###   #### #####  ####      
###########   ###########  ####     ###  ###########          ###     ######### #########  ###   ####  ####        #####     ######### ######## ###### ####  ###   ####  ##########      
#########     #########    ####     ####   ########           ###      ########  ########  ###   ####  ####         ####      ######## #######   ##### ####  ###   ####   #########      
                                                                                                                                                                             #####      
                                                                                                                                                                         #########       
                                                                                                                                                                         ######*/ 
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IVesting
{
    function claim(uint8 _round) external;
    function calculateUnlockedTokens(address _address, uint8 _round, uint48 _date) external view returns (uint256 result);
}
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
contract DDAOTeamVestingProxy is AccessControl
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	address public VestingAddress;
	address public TokenAddress;

	constructor() 
	{
	    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
	    // DDAO Admin address
	    _setupRole(DEFAULT_ADMIN_ROLE, 0x208b02f98d36983982eA9c0cdC6B3208e0f198A3);
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

        function VestingAddrSet(address addr)public virtual onlyAdmin
        {
                VestingAddress = addr;
        }
        function TokenAddrSet(address addr)public virtual onlyAdmin
        {
                TokenAddress = addr;
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
	function Claim()public
	{
		require(VestingAddress != address(0),'VestingAddress not installed');
		require(TokenWaitForClaim() <= TokenBalance(),"Not enough tokens aDDAO");
		require(TokenWaitForClaim() <= TokenAllowance(),"Insufficient allowance aDDAO for VestingContract");
		IVesting(VestingAddress).claim(2);
	}
        function TokenWaitForClaim()public view returns(uint256 amount)
	{
		amount = IVesting(VestingAddress).calculateUnlockedTokens(address(this),2,0);
	}
	function TokenAllowance()public view returns(uint256 amount)
	{
	        amount = IToken(TokenAddress).allowance(address(this), VestingAddress);
	}
	function TokenBalance()public view returns(uint256 amount)
	{
	        amount = IToken(TokenAddress).balanceOf(address(this));
	}
	function TokenApproveAll()public onlyAdmin 
	{
		uint256 amount = 1680000000000000000000000;
	        IToken(TokenAddress).approve(VestingAddress,amount);
	}
	function TokenApprove(uint256 amount)public onlyAdmin 
	{
	        IToken(TokenAddress).approve(VestingAddress,amount);
	}

}