pragma solidity ^0.5.16;

import "./StandardToken.sol";

contract TAFIN is StandardToken {
    string public name = "Test AFIN";
    string public symbol = "TAFIN";
    uint256 public decimals = 8;

    function showMeTheMoney(address _to, uint256 _value) public {
        totalSupply += _value;
        balances[_to] += _value;
        emit Transfer(address(0), _to, _value);
    }
}