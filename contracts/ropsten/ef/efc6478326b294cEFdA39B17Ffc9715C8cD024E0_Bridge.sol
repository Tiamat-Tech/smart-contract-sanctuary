// contracts/Box.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// https://docs.openzeppelin.com/contracts/3.x/api/gsn#GSNRecipient-_msgSender--
//import "@openzeppelin/contracts/GSN/GSNRecipient.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Bridge is AccessControl  {
    using SafeMath for uint256;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ADMIN_ROLE");


    uint[] public txs;
    uint256 public tx_id;
    uint256 public tx_count;
    mapping (address => mapping (uint => address)) public pairs_address;
    mapping (address => mapping (uint256 => uint256)) public sender_tx;
    mapping (address => uint256) public sender_tx_count;
//    uint256 private _value;
//    Auth private _auth;


//    event TxAdded(uint256 value);

    constructor() {
        tx_count = 0;
//        _auth = new Auth(msg.sender);
//        _setupRole(ADMIN_ROLE,_msgSender());
	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
//	addAdmin(0x000000000000000000636F6e736F6c652e6c6f67);
//	_showAdmRole();

    }


    function txCount() public view returns (uint256){
	return tx_count;
    }

    function bridgeAdd() public {
	tx_count = tx_count.add(1);
	sender_tx_count[_msgSender()] = sender_tx_count[msg.sender].add(1);
    }
    function viewSender() public view returns (address){
//	string memory view_serder_addr;
//	view_serder_addr = 'ya';
	return _msgSender();
    }
    function addAdmin(address account) public  onlyRole(ADMIN_ROLE){
	grantRole(ADMIN_ROLE, account);
    }
    function removeAdmin(address account) public virtual onlyRole(ADMIN_ROLE) {
	revokeRole(ADMIN_ROLE, account);
    }

    function _showAdmRole() public pure   returns(bytes32){
	return ADMIN_ROLE;
    }

}