// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./libs/SafeMath.sol";
import "./libs/Ownable.sol";
import "hardhat/console.sol";

abstract contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public view virtual returns (uint256);
  function transfer(address to, uint256 value) public virtual returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) public balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public override returns (bool) {
    // console.log("Trying to send %s tokens to %s", msg.sender, _value);
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }


  function balanceOf(address _owner) public override view returns (uint256 balance) {
    return balances[_owner];
  }

}

abstract contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public virtual view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public virtual returns (bool);
  function approve(address spender, uint256 value) public virtual returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract StandardToken is ERC20, BasicToken {
  using SafeMath for uint256;

  mapping (address => mapping (address => uint256)) public allowed;

  function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
    uint256 _allowance = allowed[_from][msg.sender];
    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // require (_value <= _allowance);

    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Aprove the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public override returns (bool) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    require((_value == 0) || (allowed[msg.sender][_spender] == 0), "asd");

    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) public override view returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }
}

contract BetDonutToken is StandardToken, Ownable {
  using SafeMath for uint256;

  string public name = "Bet Donut Token";
  string public symbol = "BDC";
  uint8 public decimals = 0; // @TODO 18
  BetDonutToken public token;
  address public _admin;

  uint256 public initialSupply = 1000000 * (10 ** uint256(decimals));
  event Lottery(address[] arrayAddress, uint256[] arrayAmount);
  
  constructor() {
    token = BetDonutToken(address(this)); 
    totalSupply = initialSupply;

    balances[address(msg.sender)] = initialSupply;
    emit Transfer(address(msg.sender), address(msg.sender), initialSupply);

    _admin = address(msg.sender);
  }
}