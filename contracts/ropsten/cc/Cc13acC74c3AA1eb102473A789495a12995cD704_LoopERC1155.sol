// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LoopERC1155 is ERC1155, Ownable {
  using Counters for Counters.Counter;
    
  Counters.Counter private supply;

  string public name;
  string public symbol;

  uint256 public cost = 0.01 ether;
  uint256 public maxSupply = 100;
  uint256 public maxMintAmountPerTx = 20;

  mapping(uint => string) public tokenURI;

  constructor() ERC1155("") {
    name = "LoopERC1155";
    symbol = "LE1";
  }

  modifier mintCompliance(uint256 _mintAmount) {
    require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, "Invalid mint amount!");
    require(supply.current() + _mintAmount <= maxSupply, "Max supply exceeded!");
    _;
  }

  function totalSupply() public view returns (uint256) {
    return supply.current();
  }

  function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) {
    require(msg.value >= cost * _mintAmount, "Insufficient funds!");

    _mintLoop(msg.sender, _mintAmount);
  }

  function mintForAddress(uint256 _mintAmount, address _receiver) public mintCompliance(_mintAmount) onlyOwner {
    _mintLoop(_receiver, _mintAmount);
  }

  function _mintLoop(address _receiver, uint256 _mintAmount) internal {
    for (uint256 i = 0; i < _mintAmount; i++) {
      supply.increment();
      _mint(_receiver, supply.current(), 1, "");
    }
  }

  function setURI(uint _id, string memory _uri) external onlyOwner {
    tokenURI[_id] = _uri;
    emit URI(_uri, _id);
  }

  function uri(uint _id) public override view returns (string memory) {
    return tokenURI[_id];
  }

}