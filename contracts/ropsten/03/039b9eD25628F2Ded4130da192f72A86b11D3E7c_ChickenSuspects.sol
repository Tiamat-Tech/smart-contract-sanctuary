// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ChickenSuspects is  ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    
    using SafeMath for uint256;

    uint256 public constant MAX_TOKENS = 4419;

    uint256 public constant MAX_TOKENS_PER_PURCHASE = 20;
    
    uint256 private price = 25000000000000000; // 0.025 Ether

    constructor() ERC721("Chicken Suspects", "CS") {
    }
    
    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function mint(uint256 _count, string[] memory tokenURIs) public payable {
        uint256 totalSupply = totalSupply();

        require(_count > 0 && _count < MAX_TOKENS_PER_PURCHASE + 1, "You cannot buy that much chickens in a single transaction");
        require(totalSupply + _count < MAX_TOKENS + 1, "Not enough chickens left !");
        require(msg.value >= price.mul(_count), "Ether value sent is not correct");
        
        for(uint256 i = 0; i < _count; i++){
            safeMint(msg.sender, totalSupply + i);
            _setTokenURI(totalSupply + i, tokenURIs[i]);
        }
    }

    function tokensOfOwner(address owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(_msgSender()).send(address(this).balance));
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
}