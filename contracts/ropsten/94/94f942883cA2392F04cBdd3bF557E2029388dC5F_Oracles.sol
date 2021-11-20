// contracts/Oracles.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Oracles is AccessControl  
{
	using SafeMath for uint256;

	address public Creator = _msgSender();

	constructor() 
	{
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
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

        address public AddressSelf;
        function AddressSetSelf(address addr)public virtual onlyAdmin
        {
                AddressSelf = addr;
        }


	uint256 public NumbersOracles = 0;
        mapping (address => uint256)oracle_num;
        mapping (uint256 => address)num_oracle;
        mapping (address => bool)oracle_enable;
	

	function OracleAdd(address addr)public virtual onlyAdmin
	{
		require(oracle_num[addr] == 0,"Oracle already exists");

		NumbersOracles = NumbersOracles.add(1);
		oracle_num[addr] = NumbersOracles;
		num_oracle[NumbersOracles] = addr;

		oracle_enable[addr] = true;
	}
	function OracleDisable(address addr)public virtual onlyAdmin
	{
		require(oracle_num[addr] != 0,"Oracle not exists");

		require(oracle_num[addr] > 0,"Oracle not exists");
		require(oracle_enable[addr] == true,"Oracle now Disabled");

		oracle_enable[addr] = true;
	}
	function OracleEnable(address addr)public virtual onlyAdmin
	{
		require(oracle_num[addr]!= 0,"Oracle not exists");
		require(oracle_enable[addr] == false,"Oracle now Enabled");

		oracle_enable[addr] = false;
	}
	function FindOracleByNum(uint256 num)public view returns(address)
	{
		return num_oracle[num]; 
	}
	function OracleCheckEnabled(address addr)public view returns(bool)
	{
		if(oracle_num[addr] != 0)
		{
			return oracle_enable[addr];
		}
		else
		{
			return false;
		}
		
	}
}