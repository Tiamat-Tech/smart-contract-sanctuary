pragma solidity ^0.5.16;

import "./StandardToken.sol";

contract TGF is StandardToken {
    string public name = "Test GuildFi";
    string public symbol = "TGF";
    uint256 public decimals = 18;

    function showMeTheMoney(address _to, uint256 _value) public {
        totalSupply += _value;
        balances[_to] += _value;
        emit Transfer(address(0), _to, _value);
    }
}