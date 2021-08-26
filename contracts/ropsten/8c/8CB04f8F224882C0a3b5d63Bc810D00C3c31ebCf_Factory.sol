pragma solidity ^0.8.0;

import '../token/ERC20/ERC20.sol';
import './CloneFactory.sol';

contract Factory is CloneFactory {
  ERC20[] public children;
  address masterContract;

  constructor(address _masterContract) {
    masterContract = _masterContract;
  }

  function createERC223(string memory name_, string memory symbol_) external {
    ERC20 child = ERC20(createClone(masterContract));
    child.initialize(name_, symbol_);
    children.push(child);
  }

  function getChildren() external view returns (ERC20[] memory) {
    return children;
  }
}