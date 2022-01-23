//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

import "./ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WTANFT is ERC721, ERC721Enumerable, Pausable, Ownable {
    
    string public baseURI = "https://public.nftmarketplace.vn/static/nft/";

    event UpdateBaseURI(address from, string baseUri);

    constructor() ERC721("Womentech NFT", "WTANFT") {}

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _baseUri) public onlyOwner {
        baseURI = _baseUri;
        emit UpdateBaseURI(msg.sender, baseURI);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        require(
            ownerOf(tokenId) == msg.sender,
            "ERC721: burn of token that is not own"
        );
        _burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}