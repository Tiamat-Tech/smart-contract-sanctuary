// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ChibiOriginals is ERC1155Supply, Ownable, ReentrancyGuard {
  using Address for address;

  string public name = "Chibi Originals";
  string public symbol = "CHIBI ORIGINALS";
  uint256 public collectionLimit = 1;

  string public baseTokenURI;
  mapping(address => bool) public minters;

  constructor() ERC1155("") {}

  modifier onlyMinter {
      require(tx.origin == msg.sender);
      require(msg.sender == owner() || minters[msg.sender]);
      _;
   }

   modifier collectionExists(uint256 id) {
    require(id > 0 && id <= collectionLimit, "collection does not exist");
    _;
  }

  function mintTo(address account, uint256 id, uint256 qty)
    external
    onlyMinter
    collectionExists(id)
    nonReentrant
  {
    _mint(account, id, qty, "");
  }

  function mintToMany(address[] memory to, uint256 id, uint256[] memory qty)
    external
    onlyMinter
    collectionExists(id)
    nonReentrant
  {
    require(to.length == qty.length, "address and qty must be same Length");
    for (uint256 i = 0; i < to.length; i++) {
      _mint(to[i], id, qty[i], "");
    }
  }

  function addMinter(address _minter, bool _isAllowed) external onlyOwner nonReentrant {
    minters[_minter] = _isAllowed;
  }

  function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner nonReentrant {
    baseTokenURI = _baseTokenURI;
  }

  function setCollectionLimit(uint256 _collectionLimit) external onlyOwner nonReentrant {
    collectionLimit = _collectionLimit;
  }

  function uri(uint256 id)
    override
    public
    virtual
    view
    collectionExists(id)
    returns (string memory)
  {
    return string(abi.encodePacked(baseTokenURI, Strings.toString(id)));
  }

}