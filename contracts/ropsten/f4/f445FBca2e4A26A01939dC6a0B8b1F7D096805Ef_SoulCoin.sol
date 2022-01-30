/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

// ----------------------------------------------------------------------------
// MARKETPLAYAZ CROWDSALE token contract
//
// Deployed to : 0x6f17Ed90296bA3Fe60A15fF3587B0A02D9F83337
// Symbol      : SOUL
// Name        : SOULCOIN
// Decimals    : 4
//
// ----------------------------------------------------------------------------


contract SoulCoin {
	uint totalSupply = 123000;
	
	string name = "SOULCOIN";
	uint8 decimals = 4;
	string symbol = "SOUL";
	mapping (address => uint) balances;
	mapping (address => mapping (address => uint)) allowed;

	event Transfer(
		address indexed _from,
		address indexed _to,
		uint _value
		);
		
	event Approval(
		address indexed _owner,
		address indexed _spender,
		uint _value
		);

	modifier onlyPayloadSize(uint size) {
		assert(msg.data.length == size + 4);
		_;
	} 

	function balanceOf(address _owner) public view returns (uint balance) {
		return balances[_owner];
	}

    function transfer(address _to, uint _value)public{
        require(balances[msg.sender] > _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
    }

	function transferFrom(address _from, address _to, uint _value)public{
        require(balances[_from] > _value);
        require(allowed[_from][msg.sender] >= _value);
        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        emit Approval(_from, msg.sender, allowed[_from][msg.sender]);
    }

	function approve(address _spender, uint _value) public {
		allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
	}

	function allowance(address _spender, address _owner) public view returns (uint balance) {
		return allowed[_owner][_spender];
	}



}