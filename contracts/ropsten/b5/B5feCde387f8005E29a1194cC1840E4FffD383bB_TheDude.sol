pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TheDude is ERC721 {
  using Strings for uint256;

  uint public avaliableAmount = 500;
  uint public totalMinted = 0;

  struct Dude {
    string id;
    string name;
  }

  mapping (uint => Dude) public dudes;
  mapping (string => bool) public dudeNames;

  uint[][][] internal _traitTable;
  uint internal _nonce = 0;
  uint internal _salt = 0;
  uint constant internal _maxRarityScore = 10;

  constructor () ERC721("the dudes", "dude") {
    _setTraitTable();
  }

  function claim(string memory name, uint salt) external {
      require(totalMinted < avaliableAmount, "Sale is ended");
      require(dudeNames[name] == false, "Name should be unuqie");
      dudeNames[name] = true;

      string memory dudeId = _pickDude(name);
      dudes[totalMinted].id = dudeId;
      dudes[totalMinted].name = name;

      uint tokenIdForMint = totalMinted;
      totalMinted++;
      _salt = salt;
      _safeMint(_msgSender(), tokenIdForMint);
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    string memory baseURI = _baseURI();
    return string(abi.encodePacked(baseURI, "/", dudes[tokenId].id));
  }

  function _baseURI() internal pure override returns (string memory) {
    return "thedudenft.co";
  }

  function _setTraitTable() internal {
    _traitTable.push([[0, 0], [1, 0], [2, 0], [3, 0], [4, 5], [5, 8]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0], [3, 0]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0], [3, 0]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0], [3, 0]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0]]);
    _traitTable.push([[0, 0], [1, 5], [2, 5], [3, 5]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0]]);
    _traitTable.push([[0, 0], [1, 5], [2, 5], [3, 5], [4, 5]]);
    _traitTable.push([[0, 0], [1, 0], [2, 0]]);
  }

  function _pickDude(string memory name) internal returns (string memory) {
    string memory id = "";
    for (uint i=0; i<_traitTable.length; i++) {
      uint[][] memory traitPool = _traitTable[i];
      uint trait = _pickFromTraitPool(traitPool, name);
      id = string(abi.encodePacked(id, trait.toString(), "@"));
    }
    return id;
  }

  function _pickFromTraitPool(uint[][] memory traitPool, string memory name) internal returns (uint) {
    uint r = _random(name, _maxRarityScore);
    uint foundTrait;
    uint foundScore = 0;
    for (uint i=0; i<traitPool.length; i++) {
      if (traitPool[i][1] <= r) {
        if (foundScore != traitPool[i][1]) {
          foundTrait = traitPool[i][0];
          foundScore = traitPool[i][1];
        }else{
          if (_random(name, 2) > 0) {
            foundTrait = traitPool[i][0];
          }
        }
      }
    }
    return foundTrait;
  }

  function _random(string memory name, uint limit) internal returns (uint) {
    uint r = (uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, name, _nonce, _salt)))) % limit;
    _nonce++;
    return r;
  }
}