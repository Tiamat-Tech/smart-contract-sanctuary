pragma solidity ^0.7.0;

import "hardhat/console.sol";

// This is the main building block for smart contracts.
contract Token {
    // Some string type variables to identify the token.
    // The `public` modifier makes a variable readable from outside the contract.


    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    uint256 constant private MAX_UINT256 = 2**256 - 1;
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;


    uint256 public totalSupply;
    /*
    NOTE:
    The following variables are OPTIONAL vanities. One does not have to include them.
    They allow one to customise the token contract & in no way influences the core functionality.
    Some wallets/interfaces might not even bother to look at this information.
    */
    string public name="Simon Bucks";                  //fancy name: eg Simon Bucks
    uint8 public decimals;                //How many decimals to show.
    string public symbol="SBX";                //An identifier: eg SBX

     address public owner;

     constructor() {
        // The totalSupply is assigned to transaction sender, which is the account
        // that is deploying the contract.
        balances[msg.sender] = totalSupply;
        owner = msg.sender;
    }


    // function ERC20(
    //     uint256 _initialAmount,
    //     string _tokenName,
    //     uint8 _decimalUnits,
    //     string _tokenSymbol
    // ) public {
    //     balances[msg.sender] = _initialAmount;               // Give the creator all initial tokens
    //     totalSupply = _initialAmount;                        // Update total supply
    //     name = _tokenName;                                   // Set the name for display purposes
    //     decimals = _decimalUnits;                            // Amount of decimals for display purposes
    //     symbol = _tokenSymbol;                               // Set the symbol for display purposes
    // }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 allowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && allowance >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        if (allowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}