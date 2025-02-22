// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

import './ContractReceiver.sol';
import './TokenRecipient.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

// https://www.ethereum.org/token

// ERC20 token with added ERC223 and Ethereum-Token support
//
// Blend of multiple interfaces:
// - https://theethereum.wiki/w/index.php/ERC20_Token_Standard
// - https://www.ethereum.org/token (uncontrolled, non-standard)
// - https://github.com/Dexaran/ERC23-tokens/blob/Recommended/ERC223_Token.sol

contract ERC223Token is Initializable {
  string public name;
  string public symbol;
  uint8 public decimals;
  uint256 public totalSupply;
  address public owner;

  mapping(address => uint256) balances_;
  mapping(address => mapping(address => uint256)) allowances_;

  // ERC20
  event Approval(address indexed owner, address indexed spender, uint256 value);

  event Transfer(address indexed from, address indexed to, uint256 value);
  // bytes    data ); use ERC20 version instead

  // Ethereum Token
  event Burn(address indexed from, uint256 value);

  constructor(
    uint256 initialSupply,
    string memory tokenName,
    uint8 decimalUnits,
    string memory tokenSymbol
  ) {
    totalSupply = initialSupply * 10**uint256(decimalUnits);
    balances_[msg.sender] = totalSupply;
    name = tokenName;
    decimals = decimalUnits;
    symbol = tokenSymbol;
    emit Transfer(address(0), msg.sender, totalSupply);
  }

  function initialize(
    uint256 initialSupply,
    string memory tokenName,
    uint8 decimalUnits,
    string memory tokenSymbol,
    address _owner
  ) public virtual initializer {
    totalSupply = initialSupply * 10**uint256(decimalUnits);
    balances_[msg.sender] = totalSupply;
    name = tokenName;
    decimals = decimalUnits;
    symbol = tokenSymbol;
    owner = _owner;
    emit Transfer(address(0), msg.sender, totalSupply);
  }

  // receive() external payable {
  //   revert('does not accept eth');
  // }

  // fallback() external payable {
  //   revert('calldata does not match a function');
  // }

  // ERC20
  function balanceOf(address owner) public view returns (uint256) {
    return balances_[owner];
  }

  // ERC20
  //
  // WARNING! When changing the approval amount, first set it back to zero
  // AND wait until the transaction is mined. Only afterwards set the new
  // amount. Otherwise you may be prone to a race condition attack.
  // See: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729

  function approve(address spender, uint256 value)
    public
    returns (bool success)
  {
    allowances_[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  // recommended fix for known attack on any ERC20
  function safeApprove(
    address _spender,
    uint256 _currentValue,
    uint256 _value
  ) public returns (bool success) {
    // If current allowance for _spender is equal to _currentValue, then
    // overwrite it with _value and return true, otherwise return false.

    if (allowances_[msg.sender][_spender] == _currentValue)
      return approve(_spender, _value);

    return false;
  }

  // ERC20
  function allowance(address owner, address spender)
    public
    view
    returns (uint256 remaining)
  {
    return allowances_[owner][spender];
  }

  // ERC20
  function transfer(address to, uint256 value) public returns (bool success) {
    bytes memory empty; // null
    _transfer(msg.sender, to, value, empty);
    return true;
  }

  // ERC20
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public returns (bool success) {
    require(value <= allowances_[from][msg.sender]);

    allowances_[from][msg.sender] -= value;
    bytes memory empty;
    _transfer(from, to, value, empty);

    return true;
  }

  // Ethereum Token
  function approveAndCall(
    address spender,
    uint256 value,
    bytes calldata context
  ) public returns (bool success) {
    if (approve(spender, value)) {
      tokenRecipient recip = tokenRecipient(spender);
      recip.receiveApproval(msg.sender, value, context);
      return true;
    }
    return false;
  }

  // Ethereum Token
  function burn(uint256 value) public returns (bool success) {
    require(balances_[msg.sender] >= value);
    balances_[msg.sender] -= value;
    totalSupply -= value;

    emit Burn(msg.sender, value);
    return true;
  }

  // Ethereum Token
  function burnFrom(address from, uint256 value) public returns (bool success) {
    require(balances_[from] >= value);
    require(value <= allowances_[from][msg.sender]);

    balances_[from] -= value;
    allowances_[from][msg.sender] -= value;
    totalSupply -= value;

    emit Burn(from, value);
    return true;
  }

  // ERC223 Transfer and invoke specified callback
  function transferERC223(
    address to,
    uint256 value,
    bytes calldata data,
    string calldata custom_fallback
  ) public returns (bool success) {
    _transfer(msg.sender, to, value, data);

    ContractReceiver rx = ContractReceiver(to);
    // https://docs.soliditylang.org/en/v0.5.1/050-breaking-changes.html#semantic-and-syntactic-changes
    (bool resok, bytes memory resdata) = address(rx).call(
      abi.encodeWithSignature(custom_fallback, msg.sender, value, data)
    );

    require(resok, 'custom fallback failed');
    if (resdata.length > 0) {} // suppress warning

    return true;
  }

  // ERC223 Transfer to a contract or externally-owned account
  function transferERC223ToContractOrEOA(
    address to,
    uint256 value,
    bytes calldata data
  ) public returns (bool success) {
    if (isContract(to)) {
      return transferToContract(to, value, data);
    }

    _transfer(msg.sender, to, value, data);
    return true;
  }

  // ERC223 Transfer to contract and invoke tokenFallback() method
  function transferToContract(
    address to,
    uint256 value,
    bytes calldata data
  ) private returns (bool success) {
    _transfer(msg.sender, to, value, data);

    ContractReceiver rx = ContractReceiver(to);
    rx.tokenFallback(msg.sender, value, data);
    return true;
  }

  // ERC223 fetch contract size (must be nonzero to be a contract)
  function isContract(address _addr) private view returns (bool) {
    uint256 length;
    assembly {
      length := extcodesize(_addr)
    }
    return (length > 0);
  }

  function _transfer(
    address from,
    address to,
    uint256 value,
    bytes memory data
  ) internal {
    require(to != address(0x0));
    require(balances_[from] >= value);
    require(balances_[to] + value > balances_[to]); // catch overflow

    balances_[from] -= value;
    balances_[to] += value;

    //Transfer( from, to, value, data ); ERC223-compat version
    bytes memory empty;
    empty = data;
    emit Transfer(from, to, value); // ERC20-compat version
  }
}