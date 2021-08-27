pragma solidity ^0.8.0;

import '../token/ERC20/ERC20.sol';
import '../token/ERC223/ERC223.sol';
import './CloneFactory.sol';

contract Factory is CloneFactory {
  ERC223Token[] public children;
  address masterContract;
  address public owner;

  constructor(address _masterContract) {
    masterContract = _masterContract;
  }

  function createERC223(
    uint256 initialSupply,
    string memory tokenName,
    uint8 decimalUnits,
    string memory tokenSymbol
  ) external {
    ERC223Token child = ERC223Token(createClone(masterContract));
    child.initialize(initialSupply, tokenName, decimalUnits, tokenSymbol);
    children.push(child);
    owner = msg.sender;
  }

  function getChildren() external view returns (address) {
    if (children.length > 0) {
      return address(children[children.length - 1]);
    }
    return address(children[0]);
  }
}