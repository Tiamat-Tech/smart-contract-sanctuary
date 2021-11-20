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

        mapping (address => uint256)oracle_tx_all;
	mapping (address => uint256)oracle_tx_confirm;
	mapping (address => uint256)oracle_tx_cancel;
	mapping (address => uint256)oracle_tx_final;

	function OracleAdd(address addr)public virtual onlyAdmin
	{
		require(oracle_num[addr] == 0,"Oracle already exists");

		NumbersOracles = NumbersOracles.add(1);
		oracle_num[addr] = NumbersOracles;
		num_oracle[NumbersOracles] = addr;

		oracle_enable[addr] = true;
		oracle_tx_all[addr] = 0;
		oracle_tx_confirm[addr] = 0;
		oracle_tx_cancel[addr] = 0;
		oracle_tx_final[addr] = 0;
	}
	function OracleDisable(address addr)public virtual onlyAdmin
	{
		require(oracle_num[addr] != 0,"Oracle not exists");

		require(oracle_num[addr] > 0,"Oracle not exists");
		require(oracle_enable[addr] == true,"Oracle now Disabled");

		oracle_enable[addr] = false;
	}
	function OracleEnable(address addr)public virtual onlyAdmin
	{
		require(oracle_num[addr]!= 0,"Oracle not exists");
		require(oracle_enable[addr] == false,"Oracle now Enabled");

		oracle_enable[addr] = true;
	}
	function FindOracleByNum(uint256 num)public view returns(address)
	{
		return num_oracle[num]; 
	}
	function OracleCheckEnabled(address addr)public view returns(bool)
	{
		if(oracle_num[addr]>0)
		{
			return oracle_enable[addr];
		}
		else
		{
			return false;
		}
		
	}

	function OracleTxAll(address addr)public view returns(uint256)
	{
		return oracle_tx_all[addr];
	}
	function OracleTxConfirm(address addr)public view returns(uint256)
	{
		return oracle_tx_confirm[addr];
	}
	function OracleTxCancel(address addr)public view returns(uint256)
	{
		return oracle_tx_cancel[addr];
	}
	function OracleTxFinal(address addr)public view returns(uint256)
	{
		return oracle_tx_final[addr];
	}
	function OracleChangeCountTx(address addr,string memory whats)public virtual onlyAdmin
	{
		if(keccak256(abi.encodePacked(whats)) == keccak256(abi.encodePacked("confirm")))	{ oracle_tx_confirm[addr] = oracle_tx_confirm[addr].add(1);}
		if(keccak256(abi.encodePacked(whats)) == keccak256(abi.encodePacked("cancel")))		{ oracle_tx_cancel[addr] = oracle_tx_confirm[addr].add(1);}
		if(keccak256(abi.encodePacked(whats)) == keccak256(abi.encodePacked("final")))		{ oracle_tx_final[addr] = oracle_tx_confirm[addr].add(1);}

		oracle_tx_all[addr] = oracle_tx_all[addr].add(1);		
	}
}