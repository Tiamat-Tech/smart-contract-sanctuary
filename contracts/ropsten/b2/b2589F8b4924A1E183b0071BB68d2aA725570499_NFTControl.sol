// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "Ownable.sol";

/**
@title BadgerDAO NFTControl Control
@author @swoledoteth
@notice NFTControl is the on chain source of truth for the Boost NFT Weights.
The parameter exposed by NFT Control: 
- NFT Weight
@dev All operations must be conducted by an nft control manager.
The deployer is the original manager and can add or remove managers as needed.
*/
contract NFTControl is Ownable {
  event NFTWeightChanged(address indexed _nft, uint256 indexed _id, uint256 indexed _weight);

  mapping(address => bool) public manager;
  mapping(address => mapping(uint256 => uint256)) public nftWeight;

  modifier onlyManager() {
    require(manager[msg.sender], "!manager");
    _;
  }

  constructor(address _owner) {
    manager[msg.sender] = true;
    transferOwnership(_owner);
  }

  /// @param _manager address to add as manager
  function addManager(address _manager) external onlyOwner {
    manager[_manager] = true;
  }

  /// @param _manager address to remove as manager
  function removeManager(address _manager) external onlyOwner {
    manager[_manager] = false;
  }

  /// @param _nft address of nft to set weight
  /// @param _id id of nft to set weight
  /// @param _weight weight to set wei

  function setNFTWeight(address _nft, uint256 _id, uint256 _weight)
    external
    onlyManager
  {
    nftWeight[_nft][_id] = _weight;
    emit NFTWeightChanged(_nft, _id, _weight);
  }

}