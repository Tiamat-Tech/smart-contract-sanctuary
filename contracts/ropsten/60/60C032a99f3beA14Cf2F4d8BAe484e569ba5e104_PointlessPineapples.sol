// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PointlessPineapples is ERC721Enumerable, Ownable {
  uint256 public constant Max_Pineapples = 6000;
  string _baseTokenURI = "https://gateway.pinata.cloud/ipfs/QmSTu5tX59qPQLo7CFN3HrdvcKAQjGycoxdmHjdxFZguXZ/";
  bool public isActive = false;

  constructor() ERC721("PointlessPineapples", "PP") {
  }

  function mintPP(uint _count) public payable {
    require(isActive, "Paused");
    require(_count <= 20, "Exceeds 20");
    require(totalSupply() < Max_Pineapples, "Sale ended");
    require(totalSupply() + _count <= Max_Pineapples, "Max limit");
    require(msg.value >= price(_count), "Value below price");

    for(uint i = 0; i < _count; i++){
        uint mintIndex = totalSupply();
        if (totalSupply() < Max_Pineapples) {
            _safeMint(msg.sender, mintIndex);
     }
   }
}

    function reservePineapples() public onlyOwner {        
        uint supply = totalSupply();
        uint i;
        for (i = 0; i < 50; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }
 
  function price(uint _count) public pure returns (uint256) {
    return _count * 40000000000000000;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
    _baseTokenURI = baseURI;
  }

  function walletOfOwner(address _owner) external view returns(uint256[] memory) {
    uint tokenCount = balanceOf(_owner);
    uint[] memory tokensIds = new uint256[](tokenCount);
    for(uint i = 0; i < tokenCount; i++){
      tokensIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokensIds;
  }

  function toggleActiveState() public onlyOwner {
    isActive = !isActive;
  }

  function withdrawAll() public payable onlyOwner {
    require(payable(msg.sender).send(address(this).balance));
  }
}