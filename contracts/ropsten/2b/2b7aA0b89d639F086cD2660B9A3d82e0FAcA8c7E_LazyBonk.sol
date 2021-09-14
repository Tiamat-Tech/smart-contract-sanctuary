// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract LazyBonk is Ownable, ERC721 {

  mapping(uint256 => Metadata) meta_to_date;

  struct Metadata {
    string title;
    uint index;
  }

  string private _currentBaseUrl = "https://lazy-test212.herokuapp.com/api/token/";
  constructor() ERC721("LazyBonk", "LB") {
    setBaseURI(_currentBaseUrl);
    mint("Space Fully", 3);
    mint("Space Fully", 4);
    mint("Space Fully", 5);
  }
    function _baseURI() internal view virtual override returns (string memory) {
        return _currentBaseUrl;
    }
  function mint(string memory title, uint index) internal {
      uint256 tokenId = id(index);
      
      meta_to_date[tokenId] = Metadata(title, index);
      _safeMint(msg.sender, tokenId);
  }
  //TODO Write tokenURI function
  function claim(string calldata title, uint index) external payable {
      require(msg.value == 0.01 ether, "claiming a date costs 10 finney");

      mint(title, index);
      payable(owner()).transfer(0.01 ether);
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
        _currentBaseUrl = baseURI;
  }

  function id(uint index) pure internal returns(uint256) {
    return uint256(index)-1;
  }

    function ownerOf(uint8 index) public view returns(address) {
        return ownerOf(id(index));
    }

    function titleOf(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "token not minted");
        Metadata memory date = meta_to_date[tokenId];
        return date.title;
    }

    function titleOf(uint8 index) external view returns (string memory) {
        require(_exists(id(index)), "token not minted");
        Metadata memory date = meta_to_date[id(index)];
        return date.title;
    }

    function changeTitleOf(uint8 index, string memory title) external {
        require(_exists(id(index)), "token not minted");
        changeTitleOf(id(index), title);
    }

    function changeTitleOf(uint256 tokenId, string memory title) public {
        require(_exists(tokenId), "token not minted");
        require(ownerOf(tokenId) == msg.sender, "only the owner of this date can change its title");
        meta_to_date[tokenId].title = title;
    }


}