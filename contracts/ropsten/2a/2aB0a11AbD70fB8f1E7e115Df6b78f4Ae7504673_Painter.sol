//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

import "hardhat/console.sol";

contract Painter is
  Ownable,
  ERC721Enumerable,
  ERC721Burnable,
  ReentrancyGuard,
  Mintable
{
  constructor(address _owner, address _imx) ERC721("Painter", "PAINTING") Mintable(_owner, _imx) {}

  function _mintFor(
      address to,
      uint256 id,
      bytes memory _blueprint
  ) internal override {
    require(id < 10000, "Invalid token id");
    _safeMint(to, id);
  }

    // // metadata URI
  string private _baseTokenURI;

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function tokenURI(uint256 _serialId)
    public
    view
    override
    returns (string memory)
  {
    string memory base = _baseURI();
    string memory _tokenURI = Strings.toString(_serialId);

    // If there is no base URI, return the token URI.
    if (bytes(base).length == 0) {
      return _tokenURI;
    }

    return string(abi.encodePacked(base, _tokenURI));
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  function withdrawMoney() public payable onlyOwner {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    require(success, "Transfer failed.");

    // uint256 balance = address(this).balance;
    // require(balance > 0, "ETH balance of contract is 0.");

    // // Use this, not send() or transfer() to avoid potential out of gas errors and your balance being locked forever
    // Address.sendValue(payable(owner()), balance);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 serialId
  ) internal virtual override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, serialId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}