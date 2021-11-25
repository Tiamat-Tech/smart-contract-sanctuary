// contracts/Pointer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Pointer is AccessControl  
{
//	using SafeMath for uint8;

	address public Creator = _msgSender();

	mapping (string => address)    name_contract;
	mapping (address => string)    contract_name;
	uint8 public Numbers = 0;
	mapping (uint8 => string) public  name_numbers;

	event textLog(string txt);

	constructor() 
	{
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		PointerAdd('wool',0x3d9C5491847d4f53CCC238DbF22e53b1950De12f);
		PointerAdd('woolf',0x3A8CccFcF3622407265d2685b4d5D4B1DAcd1a1B);
		PointerAdd('barn',0xc576C253573121A9e22F8c715519F2B1F64C1348);
		PointerAdd('traits',0x2FBe18e09B4Ab9196E34fB35817C28F56d551064);
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

        function PointerAdd(string memory name,address addr)public virtual onlyAdmin
        {
                bool flag = false;
                if(name_contract[name] != address(0x0))flag = true;

                require(!flag,"Pointer already exists");
                name_contract[name] = addr;

//		Numbers = Numbers.add(1);
		Numbers++;
		name_numbers[Numbers] = name;

                if(keccak256(abi.encodePacked(contract_name[addr])) == keccak256(abi.encodePacked()))contract_name[addr] = name;
        }

        function PointerChange(string memory name,address addr)public virtual onlyAdmin
        {
//                bool flag = false;
//                if(name_contract[name] == address(0x0))flag = true;
//                if(name_contract[name] == addr)flag = true;
		require(name_contract[name] != address(0x0),'Pointer does not exists');
		require(name_contract[name] == addr,'Pointer already have your new address');
//                require(flag,"Pointer does not exist or is already set to addr");

                name_contract[name] = addr;

                if(keccak256(abi.encodePacked(contract_name[addr])) == keccak256(abi.encodePacked(name)))contract_name[addr] = name;
        }

	function FindByNumber(uint8 num) public view returns(string memory)
	{
		return (name_numbers[num]);
	}

	function FindByName(string memory name) public view returns(address)
	{
		return (name_contract[name]);
	}
	function FindByAddress(address addr) public view returns(string memory)
	{
		return (contract_name[addr]);
	}
	function FindAllNames(bool flag)public view returns(string[] memory out)
	{
		if(flag)
		{
//		out = name_numbers;
//		string[] memory out;
		for (uint8 i = 0; i < Numbers; i++)
		{
			out[i] = name_numbers[i];
		}
//		return out;
		}
	}

}