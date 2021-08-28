pragma solidity ^0.8.0;

import '../token/ERC20/ERC20.sol';
import '../token/ERC223/ERC223.sol';
import './CloneFactory.sol';
import './../libraries/Ownable.sol';

contract Factory is CloneFactory, Ownable {
  address private _owner;

  ERC223Token[] public children;
  address private tokenOwner;
  address masterContract;

  // constructor(address _tokenOwner) {
  //   tokenOwner = _tokenOwner;
  // }

  function setMasterContract(address _masterContract) external onlyOwner {
    masterContract = _masterContract;
  }

  function createERC223(
    uint256 initialSupply,
    string memory tokenName,
    uint8 decimalUnits,
    string memory tokenSymbol
  ) external {
    ERC223Token child = ERC223Token(createClone(masterContract));
    child.initialize(
      _owner,
      initialSupply,
      tokenName,
      decimalUnits,
      tokenSymbol
    );
    children.push(child);
  }

  function getChildren()
    external
    view
    onlyOwner
    returns (address owner, address token)
  {
    if (children.length > 0) {
      return (address(_owner), address(children[children.length - 1]));
    }
    return (address(_owner), address(children[0]));
  }
}