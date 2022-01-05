// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract FlowFields is ERC721Enumerable, Ownable{
    using Counters for Counters.Counter;

    // constants
    uint256 constant FREE_ELEMENTS = 250;
    uint256 constant FREE_PURCHASE_LIMIT = 5;

    uint256 constant MAX_ELEMENTS = 1250;
    uint256 constant MAX_ELEMENTS_ONE_TIME = 10;
    uint256 constant PRICE_PER_NFT = 0.03 ether;

    // free whitelist
    mapping(address => uint256) private _freeWhiteList;

    // state variable
    bool public MINTING_PAUSED = true;
    string public baseTokenURI;
    string public _contractURI = "";

    Counters.Counter private _tokenIdTracker;

    constructor() ERC721("FlowFields", "FlowFields") {
    }

    function setPauseMinting(bool _pause) public onlyOwner {
        MINTING_PAUSED = _pause;
    }

    function publicMint(uint256 numberOfTokens) external payable {
        require(!MINTING_PAUSED, "Minting is not active");

        bool isFreeMint = totalSupply() < FREE_ELEMENTS;  
        if (isFreeMint) {   // Free Mint
            require(_freeWhiteList[msg.sender] + numberOfTokens <= FREE_PURCHASE_LIMIT, 'Free purchase exceeds max allowed');
        } else {            // None-Free Mint
            require(numberOfTokens <= MAX_ELEMENTS_ONE_TIME, "Purchase at a time excessds max allowed.");
            require(totalSupply() < MAX_ELEMENTS, 'All tokens have been minted');
            require(totalSupply() + numberOfTokens < MAX_ELEMENTS, 'Purchase would exceed max supply');
            require(PRICE_PER_NFT * numberOfTokens <= msg.value, 'ETH amount is not sufficient');
        }

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _tokenIdTracker.increment();
            _safeMint(msg.sender, _tokenIdTracker.current());

            if (isFreeMint) {
                _freeWhiteList[msg.sender] += 1;
            }  
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        payable(msg.sender).transfer(balance);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
}