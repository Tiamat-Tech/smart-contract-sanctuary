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
    uint256 public constant maxAstroPurchase = 30;
    uint256 public MAX_APES = 10000;
    uint256 public constant astroPrice = 70000000000000000; //0.07 ETH

    constructor() ERC721("NudevNFT", "NDNFT") {}

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

    /**
     * Mints Bored Astro
     */
    function mintAstro(uint256 numberOfTokens) public payable {
        require(
            numberOfTokens <= maxAstroPurchase,
            "Can only mint 30 tokens at a time"
        );
        require(
            totalSupply().add(numberOfTokens) <= MAX_APES,
            "Purchase would exceed max supply of Astro"
        );
        require(
            astroPrice.mul(numberOfTokens) <= msg.value,
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