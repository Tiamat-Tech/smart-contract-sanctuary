// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract WhatTheCommit is ERC721PresetMinterPauserAutoId, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    address public constant DEVELOPER_ADDRESS = 0xC006562812F7Adf75FA0aDCE5f02C33E070e0ada;
    
    uint public MAX_TOKENS = 10000;
    uint public TOKENS_PRESERVED_FOR_DEV = 2;
    
    uint public MIN_PRICE = 0.01 ether;
    uint public MAX_PRICE = 0.03 ether;
    
    uint public TOKEN_LOCK_TIMESTAMP = 1666613459;
    
    bool public SALE_STARTED = false;

    mapping (uint => uint) public tokenLockedFromTimestamp;

    constructor() ERC721PresetMinterPauserAutoId("WhatTheCommit", "WTC", "doxxing_info") {}

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        require(from != DEVELOPER_ADDRESS || tokenLockedFromTimestamp[tokenId] > block.timestamp, "WhatTheCommit: Token locked");
        
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function preMint() public onlyOwner {
        for (uint i = 0; i < TOKENS_PRESERVED_FOR_DEV; i++){
            tokenLockedFromTimestamp[_tokenIds.current()] = TOKEN_LOCK_TIMESTAMP;
            _tokenIds.increment();
            
            super.mint(address(DEVELOPER_ADDRESS));
        }
    }

    function mint(uint256 numTokens) public payable {
        require(SALE_STARTED == true, "Sale hasn't started yet");
        require(totalSupply() < MAX_TOKENS, "Sale has already ended");
      
        require(_tokenIds.current() + numTokens <= MAX_TOKENS, "Not enough tokens left");
        
        require(MIN_PRICE * numTokens <= msg.value && MAX_PRICE * numTokens >= msg.value, "Ether value sent is not correct");
        
        for (uint i = 0; i < numTokens; i++){
            _tokenIds.increment();
                     
            super.mint(msg.sender);
        }
    }
    
    function startSale() public onlyOwner {
        SALE_STARTED = true;
    }
    
    function pauseSale() public onlyOwner {
        SALE_STARTED = false;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(super.tokenURI(tokenId),".json"));
    }
}