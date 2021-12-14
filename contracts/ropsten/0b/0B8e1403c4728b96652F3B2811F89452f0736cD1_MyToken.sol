//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyToken is ERC721URIStorage, Ownable {

    address[] public whitelistedAddresses;
    mapping(address => uint256) public NFTperAddress;
    uint256 public nftWhiteListedAddressLimit = 7;
    uint256 public nftNonWhiteListedAddressLimit = 3;
    uint public constant PRICE = 0.05 ether;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("MyToken", "MTK") {}

    function addAddress(address _address) public onlyOwner {
        whitelistedAddresses.push(_address);
    }

    function removeAddress(uint id) public onlyOwner {
        delete whitelistedAddresses[id];
    }

    function mintNFT(address recipient, string memory tokenURI) public payable {
        bool whiteListAdd = false;
        for(uint i=0; i < whitelistedAddresses.length; i++)
        {
            if(recipient == whitelistedAddresses[i])
            {
                whiteListAdd = true;
            }
        }
        if(whiteListAdd)
        {
            require( NFTperAddress[recipient] < nftWhiteListedAddressLimit, 'Limit Exceded');
            require(msg.value <= PRICE, "Not enough ether to purchase NFTs.");
            _tokenIdCounter.increment();
            _mint(recipient, _tokenIdCounter.current());
            _setTokenURI(_tokenIdCounter.current(), tokenURI);
            uint currentCount = NFTperAddress[recipient];
            currentCount = currentCount + 1;
            NFTperAddress[recipient] = currentCount;
        }
        else
        {
            require( NFTperAddress[recipient] < nftNonWhiteListedAddressLimit, 'Limit Exceded');
            require(msg.value >= PRICE, "Not enough ether to purchase NFTs.");
            _tokenIdCounter.increment();
            _mint(recipient, _tokenIdCounter.current());
            _setTokenURI(_tokenIdCounter.current(), tokenURI);
            uint currentCount = NFTperAddress[recipient];
            currentCount = currentCount + 1;
            NFTperAddress[recipient] = currentCount;
        }
    }
}