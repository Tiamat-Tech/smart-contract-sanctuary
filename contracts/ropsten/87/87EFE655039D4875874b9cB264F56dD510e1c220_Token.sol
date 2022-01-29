/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

contract Token{
    string constant name = "SHAcoin";
    string constant symbol = "SHA";
    uint8 constant decimals = 100;
    uint totalSupply;
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    function mint(address who, uint howmatch) public
    {
        totalSupply += howmatch;
        balances[who] += howmatch;
    }

    function balanceOf(address who) public view returns(uint)
    {
        return(balances[who]);
    }

    function balanceOf() public view returns(uint)
    {
        return(balances[address(this)]);
    }

    function transfer(address who, uint howmatch) public
    {
        if(balances[address(this)] >= howmatch){
            emit Transfer(address(this), who, howmatch);
            balances[address(this)] -= howmatch;
            balances[who] += howmatch;
        }
    }

    function transferFrom(address from, address who, uint howmatch) public
    {
        if(allowance(from, who) >= howmatch)
        {
            if(balances[from] >= howmatch){
                emit Transfer(from, who, howmatch);
                balances[from] -= howmatch;
                balances[who] += howmatch;
                allowed[from][who] -= howmatch;
                emit Approval(from, who, allowed[from][who]);
            }
        }
    }

    function approveAdder(address _spender, uint _value) public
    {
        emit Approval(address(this), _spender, _value);
        allowed[address(this)][_spender] = _value;
    }

    function allowance(address _from, address _spender) public view returns(uint)
    {
        return(allowed[_from][_spender]);
    }

    event Transfer(address _from, address _spender, uint howmatch);

    event Approval(address _from, address _spender, uint howmatch);
}