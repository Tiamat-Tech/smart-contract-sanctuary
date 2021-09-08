// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Domino is ERC721URIStorage,ERC721Enumerable {

    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;


    Counters.Counter private _tokenIdTracker;

    uint public mintPrice;
    IERC20 public dom;
    address public dead = 0x000000000000000000000000000000000000dEaD;

    event Mint(address indexed minter, address indexed holder, string _tokenURI,string _tag);

    constructor(string memory _name, string memory _symbol, IERC20 _dom, uint _mintPrice) ERC721(_name,_symbol) {
        dom = _dom;
        mintPrice = _mintPrice;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "ipfs:/";
    }

    function mint(address to, string memory _tokenURI, string memory _tag) public virtual returns(uint tokenId)  {
        dom.safeTransferFrom(msg.sender, dead, mintPrice);
        tokenId = _tokenIdTracker.current();
        _mint(to, tokenId);
        _setTokenURI(tokenId,_tokenURI);
        _tokenIdTracker.increment();    
        emit Mint(msg.sender,to,_tokenURI,_tag);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721,ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721,ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from,address to,uint256 tokenId) internal virtual override(ERC721Enumerable,ERC721) {
        super._beforeTokenTransfer(from,to,tokenId);
    }

}