// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./token/ERC721/ERC721.sol";
import "./access/Ownable.sol";

/**
 * @title Nudev NFT Contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract NFT is ERC721, Ownable {
    using SafeMath for uint256;
    uint256 public constant maxCrapPurchase = 10;
    uint256 public MAX_APES = 10000;
    uint256 public constant CrapPrice = 69000000000000000; //0.069 ETH

    constructor() ERC721("NudevNFT1", "NDNFT1") {}

    function mint() public {
        uint256 mintIndex = totalSupply();
        _safeMint(msg.sender, mintIndex);
    }

    function mint(string memory uri) public {
        uint256 mintIndex = totalSupply();
        _safeMint(msg.sender, mintIndex);
        _setTokenURI(mintIndex, uri);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.transfer(balance);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    /**
     * Set some Bored Apes aside
     */
    function reserveCrap() public onlyOwner {        
        uint supply = totalSupply();
        uint i;
        for (i = 0; i < 30; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    /**
     * Mints Bored Crap
     */
    function mintCrap(uint256 numberOfTokens) public payable {
        require(
            numberOfTokens <= maxCrapPurchase,
            "Can only mint 10 tokens at a time"
        );
        require(
            totalSupply().add(numberOfTokens) <= MAX_APES,
            "Purchase would exceed max supply of Crap"
        );
        require(
            CrapPrice.mul(numberOfTokens) <= msg.value,
            "Ether value sent is not correct"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = totalSupply();
            if (totalSupply() < MAX_APES) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }
}