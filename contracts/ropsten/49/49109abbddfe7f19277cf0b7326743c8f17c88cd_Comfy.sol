/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.7 <0.9.0;

contract Comfy {
    string constant public name = "Comfy";
    string constant public symbol = "COMF";
    uint8 constant public decimals = 3;

    uint public totalSupply = 0;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    event Transfer(address _from, address _to, uint _value);
    event Approval(address _from, address _spender, uint _value);

    address immutable owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function mint(address _address, uint _value) public onlyOwner {
        balances[_address] += _value;
        totalSupply += _value;
    }

    function balanceOf(address _address) public view returns (uint) {
        return balances[_address];
    }

    function balanceOf() public view returns (uint) {
        return balances[msg.sender];
    }

    function transfer_(address _from, address _to, uint _value) internal {
        require(balances[_from] >= _value);
        balances[_from] -= _value;
        balances[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public {
        require(allowed[_from][msg.sender] >= _value);
        allowed[_from][msg.sender] -= _value;
        transfer_(_from, _to, _value);
    }

    function transfer(address _to, uint _value) public {
        transfer_(msg.sender, _to, _value);
    }

    function approve(address _spender, uint _value) public {
         allowed[msg.sender][_spender] = _value;
         emit Approval(msg.sender, _spender, _value);
    }

    function allowance(address _from, address _spender) public view returns(uint) {
        return allowed[_from][_spender];
    }
}