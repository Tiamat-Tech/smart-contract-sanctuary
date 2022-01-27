//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract nftee is ERC721URIStorage {
    // Libraries
    using Counters for Counters.Counter;
    // Define contract owner
    address private _owner;
    // Token ID: Token counter
    Counters.Counter private _tokenIdCounter;
    // Price: The amount of ether required to buy 1 NFT.
    uint256 private _tokenPrice = 0.01 ether; // 0.025 ETH

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor() public ERC721("nftee_collectible", "NFTEE") {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

    function say_hi() public pure returns (string memory) {
        return "Hi from the nftee teams!";
    }

    function change_price(uint256 _price) public onlyOwner {
        _tokenPrice = _price;
    }

    function withdraw() public onlyOwner {
        payable(_owner).transfer(address(this).balance);
    }

    function mint_nftee(address recipient, string memory tokenURI)
        public
        payable
        returns (uint256)
    {
        _tokenIdCounter.increment();

        // set a token ID
        uint256 newTokenId = _tokenIdCounter.current();

        // safely mint token for the person that called the function
        _safeMint(recipient, newTokenId);

        // set token metadata
        _setTokenURI(newTokenId, tokenURI);

        // Event (from, to, tokenId)
        emit Transfer(address(this), msg.sender, newTokenId);

        //return the token id
        return newTokenId;
    }
}