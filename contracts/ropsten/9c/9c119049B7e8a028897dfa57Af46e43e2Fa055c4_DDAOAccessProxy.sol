// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IProxy
{
//        function decimals() external view  returns (uint8);
//        function allowance(address owner,address spender)  external view returns (uint256);
	function balanceOf(address addr,uint8 level) external view returns(uint256);
}

contract DDAOAccessProxy is AccessControl
{
	constructor()
	{
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
	
	}

	address public AccessGuru;

	function AccessGuruAddress(address addr)public onlyAdmin()
	{
		AccessGuru = addr;
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

	function balanceOf(address addr,uint8 level) public view returns(uint256)
	{
		return IProxy(AccessGuru).balanceOf(addr,level);
	}
}