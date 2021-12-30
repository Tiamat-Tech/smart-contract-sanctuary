// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Color is ERC721, ERC721Enumerable  {
    string[] public colors; //maybe bytes8 ? for optimization
    uint public _id;
    mapping(string => bool) _colorExists;

    constructor() public ERC721("Color", "COLORZ") {    }

    function mint(string memory _color) public{
        require(!_colorExists[_color]);
        require(bytes(_color).length == 7);
        colors.push(_color); //mapping may be more efficient
        _id = colors.length;
        _colorExists[_color] = true;
        _mint(msg.sender, _id);
    }

    //required function overrides for ERC721Enumerable
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal override(ERC721, ERC721Enumerable){
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view
    override(ERC721, ERC721Enumerable) returns (bool){
        return super.supportsInterface(interfaceId);
    }

    function totalSupply() public view override returns (uint256) {
      return _id;
    }

}