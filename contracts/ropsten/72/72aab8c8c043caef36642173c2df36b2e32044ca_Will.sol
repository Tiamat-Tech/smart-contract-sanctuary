/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Will {
    address _admin;
    mapping(address => address)  _heirs;
    mapping(address => uint) _balances;
    event Create(address indexed owner, address indexed heir, uint amount);
    event Deceased(address indexed owner, address indexed heir, uint amount);

    constructor() {
        _admin = msg.sender;
    }

    // Fucntion Create phinaikam
    function create(address heir) public payable {
        require(msg.value > 0, "amount is zero ");
        require(_balances[msg.sender] <= 0, "already exists");

        _heirs[msg.sender] = heir;
        _balances[msg.sender] = msg.value;
        emit Create(msg.sender, heir, msg.value);

    }

    // Function Jaeng tai
    function deceased(address owner) public {
        require(msg.sender == _admin, "unauthorized");
        require(_balances[owner] > 0, "no testament");

        emit Deceased(owner, _heirs[owner], _balances[owner]);
        payable(_heirs[owner]).transfer(_balances[owner]);
        _heirs[owner] = address(0);
        _balances[owner] = 0;

    }

    // Function Berng Sun Ya
    function contracts(address owner) public view returns (address heir, uint balances) {
        return (_heirs[owner], _balances[owner]);
    }
}