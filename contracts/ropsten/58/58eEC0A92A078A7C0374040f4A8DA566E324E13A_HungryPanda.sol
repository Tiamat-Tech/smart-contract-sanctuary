// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract HungryPanda is Ownable, ERC721Enumerable {

  uint public constant MAX_SUPPLY = 10000;
  string public baseTokenURI;
  bool public saleActive;
  bool public sealedTokenURI;

  constructor(string memory _baseTokenURI) ERC721("HungryPandas", "PANDAS")  {
    sealedTokenURI = false;
    saleActive = false;
    setBaseTokenURI(_baseTokenURI);
  }

  function flipActiveSwitch() external onlyOwner {
    saleActive = !saleActive;
  }

  function sealTokenURI() external onlyOwner {
    sealedTokenURI = true;
  }

  function setBaseTokenURI(string memory _baseTokenURI) public onlyOwner {
    require(!sealedTokenURI, "baseURI is sealed");
    baseTokenURI = _baseTokenURI;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function price(uint _amount) public pure returns (uint) {
    uint _price = 80000000000000000 * _amount; // 0.08 ETH per panda
    return _price;
  }

  function mintPandas(address _to, uint _amount) public payable {
    if (msg.sender != owner()) {
        require(saleActive, "Sale not active");
    }
    require(msg.value >= price(_amount), "Not enough ETH sent");
    require(totalSupply() < MAX_SUPPLY, "Max supply reached");
    require(totalSupply() + _amount <= MAX_SUPPLY, "Exceeds max supply");
    require(_amount <= 20, "Max 20 per txn");

    for (uint i = 0; i < _amount; i++) {
        _safeMint(_to, totalSupply());
    }
  }

  function withdraw() external onlyOwner {
      payable(owner()).transfer(address(this).balance);
  }

  function pandasByOwner(address _owner) external view returns(uint256[] memory) {
      uint tokenBalance = balanceOf(_owner);

      uint256[] memory tokenIds = new uint256[](tokenBalance);
      for(uint i = 0; i < tokenBalance; i++){
          tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
      }

      return tokenIds;
  }




}