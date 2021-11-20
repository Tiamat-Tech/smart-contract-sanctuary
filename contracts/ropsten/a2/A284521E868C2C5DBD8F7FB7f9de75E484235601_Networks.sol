// contracts/Networks.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Networks is AccessControl  
{
	using SafeMath for uint256;


	address public Creator = _msgSender();
	uint public NetworkCount = 1;
	mapping (uint => uint)    network_ids;


	event textLog(string txt);
	struct Network
	{
		uint id;
		bool disabled;
		uint256 chain_id;
		string name;
		string url;
	}
	mapping (uint => Network) network_list;
	Network this_network;

		

	constructor() 
	{
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

		NetworkModify(2,true,5,"goerli","http://10.0.103.156:8545/");
		NetworkModify(4,true,97,"bsctest","http://10.0.103.153:8545/");
		NetworkModify(1,true,4,"rinkeby","http://10.0.103.157:8545/");
		NetworkModify(3,true,3,"ropsten","http://10.0.9.191:8545/");
		NetworkModify(5,true,137,"matic","http://10.0.103.172:8545/");

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

	function NetworkModify(uint id, bool disabled, uint256 chain_id,string memory name,string memory url)public virtual onlyAdmin
	{
		network_list[id] = Network(id,disabled,chain_id,name,url);
		if(network_ids[id] == 0)
		{
			network_ids[id] = NetworkCount;
			NetworkCount = NetworkCount.add(1);
		}
	}

	function NetworkView(uint id)public view returns(uint,bool,uint256,string memory,string memory)
	{
		return (network_list[id].id, network_list[id].disabled, network_list[id].chain_id, network_list[id].name, network_list[id].url);
	}
	function NetworkView2(uint id)public view returns(Network memory)
	{
		return(network_list[id]);
	}
	function NetworkViewSequential(uint id2)public view returns(uint,bool,uint256,string memory,string memory)
	{
		uint id;
		id = network_ids[id2];
		return (network_list[id].id, network_list[id].disabled, network_list[id].chain_id, network_list[id].name, network_list[id].url);
	}
	/*
	function NetworkList() public view returns(Network[] memory out)
	{
		uint id;
		Network out[];
		for (uint i = 1; i <= NetworkCount; i=i.add(1)) 
		{
			id = network_ids[id];
			out[] = network_list[id];
			//return (network_list[id]);
		}
	}
	*/
/*
	function aaa()public view returns(Network[] memory)
	{
		uint id;
		for (uint i = 1; i <= NetworkCount; i=i.add(1))
		{
			id = network_ids[id];
			this_network = network_list[id];
			return (this_network);
		}

	}
*/
/*	function NetworkListByKey() public view returns(uint[] memory,bool[] memory,uint256[] memory,string[] memory,string[] memory)
	{
		require(start,'Insert 1 for Start');
		uint id;

		for (uint i = 1; i <= NetworkCount; i=i.add(1))
		{
			id = network_ids[id];
			return (network_list[id].id, network_list[id].disabled, network_list[id].chain_id, network_list[id].name, network_list[id].url);

		}
	}
*/
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