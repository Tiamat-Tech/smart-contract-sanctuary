// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../library/Owned.sol";
import "../library/Finalizable.sol";
import "../ledger/Ledger.sol";

contract Controller is Owned, Finalizable {
    Ledger public ledger;
    address public token;

    function setToken(address _token) public onlyOwner {
        token = _token;
    }

    function setLedger(address _ledger) public onlyOwner {
        ledger = Ledger(_ledger);
    }

    modifier onlyToken() {
        require(msg.sender == token);
        _;
    }

    function totalSupply() public view returns (uint256) {
        return ledger.totalSupply();
    }

    function balanceOf(address _a) public view onlyToken returns (uint256) {
        return Ledger(ledger).balanceOf(_a);
    }

    function allowance(address _owner, address _spender)
        public
        view
        onlyToken
        returns (uint256)
    {
        return ledger.allowance(_owner, _spender);
    }

    function transfer(
        address _from,
        address _to,
        uint256 _value
    ) public onlyToken returns (bool success) {
        return ledger.transfer(_from, _to, _value);
    }

    function transferFrom(
        address _spender,
        address _from,
        address _to,
        uint256 _value
    ) public onlyToken returns (bool success) {
        return ledger.transferFrom(_spender, _from, _to, _value);
    }

    function approve(
        address _owner,
        address _spender,
        uint256 _value
    ) public onlyToken returns (bool success) {
        return ledger.approve(_owner, _spender, _value);
    }

    function increaseApproval(
        address _owner,
        address _spender,
        uint256 _addedValue
    ) public onlyToken returns (bool success) {
        return ledger.increaseApproval(_owner, _spender, _addedValue);
    }

    function decreaseApproval(
        address _owner,
        address _spender,
        uint256 _subtractedValue
    ) public onlyToken returns (bool success) {
        return ledger.decreaseApproval(_owner, _spender, _subtractedValue);
    }

    function burn(address _owner, uint256 _amount) public onlyToken {
        ledger.burn(_owner, _amount);
    }
}