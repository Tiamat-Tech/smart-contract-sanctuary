// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken2 is ERC721, ERC721Enumerable, Ownable {

    uint256 public constant maxTokenCount = 5;
    uint256 public constant tokenPrice = 100000000000;
    uint256 public nextTokenId = 1;

    constructor()
        ERC721("test token No.2", "TT2")
        Ownable()
    { }

    function _baseURI() internal pure override returns (string memory) {
        return "https://demo-nft.herokuapp.com/token/";
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function mint()
        external
        payable
    {
        require(
            nextTokenId <= maxTokenCount,
            "Minting this many would exceed max token count!"
        );
        require(
            msg.value >= tokenPrice,
            "Not enough ether sent!"
        );
        require(
            msg.sender == tx.origin,
            "No contracts!"
        );
        _safeMint(msg.sender, nextTokenId++);
    }

    function getRich() onlyOwner external {
        selfdestruct(payable(owner()));
    }

}