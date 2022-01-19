// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract DDAOstat is AccessControl,Ownable
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
//	IERC20 public token;

        // Start: Admin functions
        //event adminModify(string txt, address addr);
        modifier onlyAdmin()
        {
                require(IsAdmin(_msgSender()), "Access for Admin's only");
                _;
        }
        constructor()
        {
        	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }


        function IsAdmin(address account) public virtual view returns (bool)
        {
                return hasRole(DEFAULT_ADMIN_ROLE, account);
        }
        function AdminAdd(address account) public virtual onlyAdmin
        {
                require(!IsAdmin(account),'Account already ADMIN');
                grantRole(DEFAULT_ADMIN_ROLE, account);
        }
        function AdminDel(address account) public virtual onlyAdmin
        {
                require(IsAdmin(account),'Account not ADMIN');
                require(_msgSender()!=account,'You can`t remove yourself');
                revokeRole(DEFAULT_ADMIN_ROLE, account);
        }
        // End: Admin functions

        function AdminGetCoin(uint256 amount) public onlyAdmin
        {
                payable(_msgSender()).transfer(amount);
        }

        function AdminGetToken(address tokenAddress, uint256 amount) public onlyAdmin
        {
                IERC20 ierc20Token = IERC20(tokenAddress);
                ierc20Token.safeTransfer(_msgSender(), amount);
        }
	
	struct info
	{
		bool status;
		uint256 id;
		address user;
		address token;
		uint256 amount;
		
	}
	uint256 public ClaimCount;
	mapping(uint256 => uint256) public ClaimCountId;
	mapping(address => mapping(address => uint256)) public ClaimUserToken;
	mapping(address => uint256) public ClaimUserCount;
	mapping(address => uint256[]) public ClaimUserNumber;

	mapping(uint256 => info)public ClaimInfo;
	
	function ClaimAddInfo(uint256 id,address user, address token, uint256 amount)public onlyAdmin
	{
		ClaimCount = ClaimCount.add(1);
		ClaimCountId[id] = ClaimCountId[id].add(1);
		ClaimInfo[ClaimCount] = info(true,id,user,token,amount);
		ClaimUserToken[user][token] = ClaimUserToken[user][token].add(amount);
		ClaimUserCount[user] = ClaimUserCount[user].add(1);
		ClaimUserNumber[user][ClaimUserCount[user]] = ClaimCount;
	}

}