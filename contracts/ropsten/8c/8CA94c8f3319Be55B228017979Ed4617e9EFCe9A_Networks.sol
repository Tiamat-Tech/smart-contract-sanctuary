// contracts/Networks.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Networks is AccessControl  {
	using SafeMath for uint256;


	address public Creator = _msgSender();

	event textLog(string txt);
	struct Network
	{
		uint id;
		bool disabled;
		bytes32 chain_id;
		bytes32 name;
		bytes32 url;
	}
	mapping (uint => Network) network_list;
	Network this_network;

		

	constructor() 
	{
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

		NetworkModify(1,true,"rinkeby","4","http://10.0.103.157:8545/");
		NetworkModify(2,true,"goerli","5","http://10.0.103.156:8545/");
		NetworkModify(3,true,"ropsten","3","http://10.0.9.191:8545/");
		NetworkModify(4,true,"bsctest","97","http://10.0.103.153:8545/");
		NetworkModify(5,true,"matic","137","http://10.0.103.172:8545/");

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

	function NetworkModify(uint id, bool disabled, bytes32 chain_id,bytes32 name,bytes32 url)public virtual onlyAdmin
	{
		network_list[id] = Network(id,disabled,chain_id,name,url);
	}

	function NetworkView(uint id)public view returns(uint,bool,bytes32,bytes32,bytes32)
	{
		return (network_list[id].id, network_list[id].disabled, network_list[id].chain_id, network_list[id].name, network_list[id].url);
	}
//	function NetworkList(address token1) view returns(uint32 network,address pair2)
//	{
//		for (uint i = 0; i < pairs_address[token1].length; i++) 
//		if ( == value) return i;
//		return uint(-1);
//		
//	}
	function CreatorView()public view returns(address)
	{
		return Creator;
	}
//	string test_string = 'Show';
//	function for_test()public view returns (bool)
//	{
//		return false;
//	}

}