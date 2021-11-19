// contracts/Bridge.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract TokenPairs is AccessControl  {
	using SafeMath for uint256;

	mapping (address => mapping (uint => address)) 	public pairs_address;

	mapping (address => address) 	public token_exists;

	event textLog(string txt);

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

	function PairAdd(address token1,uint32 network,address token2)public virtual onlyAdmin
	{
		bool flag = false;
		if(pairs_address[token1][network] == address(0x0))flag = true;
		
		require(!flag,"Token Pair already exists");
		pairs_address[token1][network] = token2;
	}
	function PairRemove(address token1,uint32 network,address token2)public virtual onlyAdmin
	{
		bool flag = false;
		if(pairs_address[token1][network] == address(0x0))flag = true;
		
		require(flag,"Token Pair does not exist or is deleted");
		pairs_address[token1][network] = token2;
	}

	function PairChange(address token1,uint32 network,address token2)public virtual onlyAdmin
	{
		bool flag = false;
		if(pairs_address[token1][network] == address(0x0))flag = true;
		if(pairs_address[token1][network] == token2)flag = true;
		require(flag,"Token Pair does not exist or is already set to token2");

		pairs_address[token1][network] = token2;
	}

	function PairView(address token1,uint32 network)public view returns(address)
	{
		return pairs_address[token1][network];
	}
//	function PairList(address token1) view returns(uint32 network,address pair2)
//	{
//		for (uint i = 0; i < pairs_address[token1].length; i++) 
//		if ( == value) return i;
//		return uint(-1);
//		
//	}
}