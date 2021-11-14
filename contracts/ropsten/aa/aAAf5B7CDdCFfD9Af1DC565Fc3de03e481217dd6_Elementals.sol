//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract Elementals is Mintable, ERC721URIStorage, ERC721Enumerable {
    string public provenance = "e1763c23da2bb124c1378080ffbdb493838f225bbebeb0a14669cd92a2bbde22";
    string private baseURI = "https://elementals.mypinata.cloud/ipfs/";

    constructor(address _owner, address _imx) ERC721("Elementals Vol. 1", "ELMTS") Mintable(_owner, _imx) {

    }

    // IMX required function
    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function setTokenURI(uint256 tokenId, string memory tokenUri) public onlyOwner {
        _setTokenURI(tokenId, tokenUri);
    }

    function setBaseURI(string memory baseUri) public onlyOwner {
        baseURI = baseUri;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) onlyOwner returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) onlyOwner {
        super._burn(tokenId);
    }
}