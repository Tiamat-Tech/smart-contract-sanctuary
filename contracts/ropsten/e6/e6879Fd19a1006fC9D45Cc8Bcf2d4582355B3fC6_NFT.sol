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
    uint public constant maxApePurchase = 30;
    uint256 public constant apePrice = 80000000000000000; //0.08 ETH

    constructor() ERC721("NudevNFT", "NDNFT") {
        
    }

    function mint() public {
        uint mintIndex = totalSupply();
        _safeMint(msg.sender, mintIndex);
    }

    function mint(string memory uri) public {
        uint mintIndex = totalSupply();
        _safeMint(msg.sender, mintIndex);
        _setTokenURI(mintIndex, uri);
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        msg.sender.transfer(balance);
    }

    /**
    * Mints Bored Apes
    */
    function mintApe(uint numberOfTokens) public payable {
        require(numberOfTokens <= maxApePurchase, "Can only mint 30 tokens at a time");
        require(apePrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }

}