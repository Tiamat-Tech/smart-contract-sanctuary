// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";

interface MongoBase {
  function initialize(
    string calldata tokenName,
    string calldata symbol,
    address contractOwner,
    address signerAddress,
    uint256 max,
    uint256 presalePrice,
    uint256 salePrice,
    uint256 maxPerTxn
  ) external;
}

contract MongoFactory {
  //Base contract (MongoBase.sol)
  address baseContract;

  //Mapping of all Clones to Owners
  mapping(address => address[]) public allClones;

  event NewClone(address _newClone, address _owner);

  constructor(address _baseContract) {
    baseContract = _baseContract;
  }

  function createClone(
    string calldata tokenName,
    string calldata symbol,
    address signerAddress,
    uint256 max,
    uint256 presalePrice,
    uint256 salePrice,
    uint256 maxPerTxn
  ) external returns (address) {
    address clone = Clones.clone(baseContract);
    MongoBase(clone).initialize(tokenName, symbol, msg.sender, signerAddress, max, presalePrice, salePrice, maxPerTxn);
    allClones[msg.sender].push(clone);
    emit NewClone(clone, msg.sender);
    return clone;
  }

  function returnClones(address _owner) external view returns (address[] memory) {
    return allClones[_owner];
  }
}