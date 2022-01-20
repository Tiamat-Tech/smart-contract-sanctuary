// SPDX-License-Identifier: MIT
pragma solidity =0.4.11;

import "../library/Finalizable.sol";
import "../library/TokenReceivable.sol";
import "../library/SafeMath.sol";
import "../controller/Controller.sol";
import "../library/IToken.sol";

contract EventDefinitions {
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}

contract Token is IToken, Finalizable, TokenReceivable, SafeMath, EventDefinitions {

  string public name = "FunFair";
  uint8 public decimals = 8;
  string public symbol = "FUN";

  Controller controller;
  address owner;

  modifier onlyController() {
    assert(msg.sender == address(controller));
    _;
  }

  function setController(address _c) onlyOwner notFinalized {
    controller = Controller(_c);
  }

  function balanceOf(address owner) constant returns (uint256) {
    return controller.balanceOf(owner);
  }

  function totalSupply() constant returns (uint) {
    return controller.totalSupply();
  }

  function allowance(address _owner, address _spender) constant returns (uint) {
    return controller.allowance(_owner, _spender);
  }

  function transfer(address _to, uint256 _value)  returns (bool) {
    require(controller.transfer(msg.sender, _to, _value));
    Transfer(msg.sender, _to, _value);
    return true;
  }

  function transferFrom(address _from, address _to, uint _value) returns (bool success) {
    require(controller.transferFrom(msg.sender, _from, _to, _value));
    Transfer(_from, _to, _value);
    return true;
  }

  function approve(address _spender, uint _value)
  onlyPayloadSize(2)
  returns (bool success) {
    //promote safe user behavior
    if (controller.allowance(msg.sender, _spender) > 0) throw;

    success = controller.approve(msg.sender, _spender, _value);
    if (success) {
      Approval(msg.sender, _spender, _value);
    }
  }

  function increaseApproval(address _spender, uint _addedValue)
  onlyPayloadSize(2)
  returns (bool success) {
    success = controller.increaseApproval(msg.sender, _spender, _addedValue);
    if (success) {
      uint newval = controller.allowance(msg.sender, _spender);
      Approval(msg.sender, _spender, newval);
    }
  }

  function decreaseApproval(address _spender, uint _subtractedValue)
  onlyPayloadSize(2)
  returns (bool success) {
    success = controller.decreaseApproval(msg.sender, _spender, _subtractedValue);
    if (success) {
      uint newval = controller.allowance(msg.sender, _spender);
      Approval(msg.sender, _spender, newval);
    }
  }

  modifier onlyPayloadSize(uint numwords) {
    assert(msg.data.length >= numwords * 32 + 4);
    _;
  }

  function burn(uint _amount) {
    controller.burn(msg.sender, _amount);
    Transfer(msg.sender, 0x0, _amount);
  }

  function controllerTransfer(address _from, address _to, uint _value)
  onlyController {
    Transfer(_from, _to, _value);
  }

  function controllerApprove(address _owner, address _spender, uint _value)
  onlyController {
    Approval(_owner, _spender, _value);
  }

  // multi-approve, multi-transfer

  bool public multilocked;

  modifier notMultilocked {
    assert(!multilocked);
    _;
  }

  //do we want lock permanent? I think so.
  function lockMultis() onlyOwner {
    multilocked = true;
  }

  // multi functions just issue events, to fix initial event history

  function multiTransfer(uint[] bits) onlyOwner notMultilocked {
    if (bits.length % 3 != 0) throw;
    for (uint i = 0; i < bits.length; i += 3) {
      address from = address(bits[i]);
      address to = address(bits[i + 1]);
      uint amount = bits[i + 2];
      Transfer(from, to, amount);
    }
  }

  function multiApprove(uint[] bits) onlyOwner notMultilocked {
    if (bits.length % 3 != 0) throw;
    for (uint i = 0; i < bits.length; i += 3) {
      address owner = address(bits[i]);
      address spender = address(bits[i + 1]);
      uint amount = bits[i + 2];
      Approval(owner, spender, amount);
    }
  }

  string public motd;

  event Motd(string message);

  function setMotd(string _m) onlyOwner {
    motd = _m;
    Motd(_m);
  }
}