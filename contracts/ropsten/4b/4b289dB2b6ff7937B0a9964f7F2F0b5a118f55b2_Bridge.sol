// contracts/Bridge.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Bridge is AccessControl  {
    using SafeMath for uint256;
//    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//    bytes32 public constant ORACLE_ROLE = keccak256("ADMIN_ROLE");

    bool public contractStoped = false;
//    uint[]  public global_txs;
//    uint256 public globsl_tx_count = 0;
    uint256  global_tx_id = 0;
    mapping (address => mapping (uint => address)) 	public pairs_address;

//    mapping (address => mapping (uint256 => uint256)) 	public sender_tx;
//    mapping (address => mapping (uint256 => uint256)) 	public sender_txs;
//    mapping (address => uint256) 			public sender_tx_id;
//    uint[] public sender_tx_id;
//    uint256 private _value;
//    Auth private _auth;


//    event TxAdded(uint256 value);
    event adminModify(string txt, address addr);
    event textLog(string txt);

    constructor() 
    {
	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

    }

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

    function ContractPause() public virtual onlyAdmin
    {
	require(!contractStoped,'The contract was already on pause');
	contractStoped = true;
	emit textLog('The contract was paused by the administrator');
    }
    function ContractResume() public virtual onlyAdmin
    {
	require(contractStoped,'The contract has not been paused');
	contractStoped = false;
	emit textLog('The contract is operating normally');
    }
    function IsContractPaused()public virtual view returns(bool)
    {
	return contractStoped;
    }

//    event BridgeAdded();
    mapping (uint256 => address)	global_tx_sender;
    mapping (uint256 => address)	global_tx_origin;
    mapping (uint256 => address)	global_tx_token;
    mapping (uint256 => uint256)	global_tx_amount;
    mapping (uint256 => uint32)		global_tx_network;
    mapping (uint256 => uint256)	global_tx_block;
    mapping (uint256 => uint256)	global_tx_unixtime;
    mapping (uint256 => uint)		global_tx_status;
    mapping (uint256 => uint)		global_tx_confirm;

//    mapping (address => uint256) public global_tx_by_sender;
//    mapping (address => uint256) public global_tx_by_token;

    mapping (address => uint256) 			sender_tx_count;
    mapping (address => mapping (uint256 => uint256))	sender_tx;

//    mapping (address => uint256) 	public global_tx_by_token_count;
//    mapping (address => mapping (uint256 => uint256))	global_tx_by_token;


	address public AddressSelf;
	function AddressSetSelf(address addr)public virtual onlyAdmin
	{
		AddressSelf = addr;
	}

	address public AddressPointer;
	function AddressSetPointer(address addr)public virtual onlyAdmin
	{
		AddressPointer = addr;
	}




    function BridgeAdd(address token,uint256 amount,uint32 network) public 
    {
//	uint256 tx_id;	
	uint256 len;

	global_tx_id = global_tx_id.add(1);
	
	uint256 id = global_tx_id;

	global_tx_sender[id]	= _msgSender();
	global_tx_origin[id]	= tx.origin;
	global_tx_token[id]	= token;
	global_tx_amount[id]	= amount;
	global_tx_network[id]	= network;
	global_tx_block[id]	= block.number;
	global_tx_unixtime[id]	= block.timestamp;

//	sender_tx_id[_msgSender()] = sender_tx_id[_msgSender()].add(1);
//	tx_id = sender_tx_id[_msgSender()];
//	sender_txs[_msgSender()][tx_id] = id;

	len = sender_tx_count[_msgSender()];
	len = len.add(1);
	sender_tx_count[_msgSender()] = len;
	sender_tx[_msgSender()][len] = id;
	
    }

    function TxGlobalInfoById(uint256 id)public view returns(address sender,address origin,address token,uint256 amount,uint32 network,uint256 blk,uint256 time, uint status,uint confirm)
    {
	bool flag = false;
	if(id < 1) flag = true;
	if(id > global_tx_id) flag = true;
	require(!flag,'ID not exists');
	sender 	= global_tx_sender[id];
	origin 	= global_tx_origin[id];
	token 	= global_tx_token[id];
	amount 	= global_tx_amount[id];
	network = global_tx_network[id];
	blk	= global_tx_block[id];
	time 	= global_tx_unixtime[id];
	status  = global_tx_status[id];
	confirm = global_tx_confirm[id];
    }

    function TxGlobalCount()public view returns(uint256)
    {
	return global_tx_id;
    }

    function TxSenderCount(address account)public view returns(uint256)
    {
	return sender_tx_count[account];
    }
    function TxSenderByNum(address account,uint256 num)public view returns(uint256)
    {
	return sender_tx[account][num];
    }

	function CheckAllowance(address token)public view returns(uint256)
	{
		
	}

}