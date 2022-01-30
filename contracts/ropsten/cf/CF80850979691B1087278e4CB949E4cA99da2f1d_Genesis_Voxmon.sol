//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT

/**
*   @title Genesis Voxmon Contract
*/

/*
██╗   ██╗ ██████╗ ██╗  ██╗███╗   ███╗ ██████╗ ███╗   ██╗
██║   ██║██╔═══██╗╚██╗██╔╝████╗ ████║██╔═══██╗████╗  ██║
██║   ██║██║   ██║ ╚███╔╝ ██╔████╔██║██║   ██║██╔██╗ ██║
╚██╗ ██╔╝██║   ██║ ██╔██╗ ██║╚██╔╝██║██║   ██║██║╚██╗██║
 ╚████╔╝ ╚██████╔╝██╔╝ ██╗██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚═══╝   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// 
contract Genesis_Voxmon is ERC721, Ownable {
    using Counters for Counters.Counter;

    /*
    *   Global Data space
    */

    // This is live supply for clarity because our re-roll mechanism causes one token to be burned
    // and a new one to be generated. So some tokens may have a higher tokenId than 10,000
    uint16 public constant MAX_SUPPLY = 10000;
    Counters.Counter private _tokensMinted;

    // count the number of rerolls so we can add to tokensMinted and get new global metadata ID during reroll 
    Counters.Counter private _tokensRerolled;
    
    uint public constant MINT_COST = 70000000 gwei; // 0.07 ether 
    uint public constant REROLL_COST = 30000000 gwei; // 0.03 ether

    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo public defaultRoyaltyInfo;

    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;
    

    // to avoid rarity sniping this will initially be a centralized domain
    // and later updated to IPFS
    string public __baseURI = "https://voxmon.io/token/";

    // this will let us differentiate that a token has been locked for 3D art visually
    string public __lockedBaseURI = "https://voxmon.io/locked/";

    // time delay for public minting
    // unix epoch time
    uint256 public startingTime;
    uint256 public artStartTime;

    mapping (uint256 => address) internal tokenIdToOwner;

    // As a reward to the early community, some members will get a number of free re-rolls 
    mapping (address => uint16) internal remainingRerolls; 

    // As a reward to the early community, some members will get free Voxmon
    mapping (address => uint16) internal remainingPreReleaseMints;

    // keep track of Voxmon which are currently undergoing transformation (staked)
    mapping (uint256 => bool) internal tokenIdToFrozenForArt;

    // since people can reroll their and we don't want to change the tokenId each time
    // we need a mapping to know what metadata to pull from the global set 
    mapping (uint256 => uint256) internal tokenIdToMetadataId;

    event artRequestedEvent(address indexed requestor, uint256 tokenId);
    event rerollEvent(address indexed requestor, uint256 tokenId, uint256 newMetadataId);
    event mintEvent(address indexed recipient, uint256 tokenId, uint256 metadataId);

    // replace these test addresses with real addresses before mint
    address[] votedWL = [
        0x633e6a774F72AfBa0C06b4165EE8cbf18EA0FAe8
    ];

    address[] earlyDiscordWL = [
        0x633e6a774F72AfBa0C06b4165EE8cbf18EA0FAe8
    ];

    address[] foundingMemberWL = [
        0x633e6a774F72AfBa0C06b4165EE8cbf18EA0FAe8
    ];

    constructor(address payable addr) ERC721("Genesis Voxmon", "VOXMN") {
        // setup freebies for people who voted on site
        for(uint i = 0; i < votedWL.length; i++) {
            remainingRerolls[votedWL[i]] = 10;
        }

        // setup freebies for people who were active in discord
        for(uint i = 0; i < earlyDiscordWL.length; i++) {
            remainingRerolls[earlyDiscordWL[i]] = 10;
            remainingPreReleaseMints[earlyDiscordWL[i]] = 1;
        }

        // setup freebies for people who were founding members
        for(uint i = 0; i < foundingMemberWL.length; i++) {
            remainingRerolls[foundingMemberWL[i]] = 25;
            remainingPreReleaseMints[foundingMemberWL[i]] = 5;
        }


        // setup starting blocknumber (mint date) 
        // Friday Feb 4th 6pm pst 
        startingTime = 1644177600;
        artStartTime = 1649228400;

        // setup royalty address
        defaultRoyaltyInfo = RoyaltyInfo(addr, 1000);
    }
    
    /*
    *   Priviledged functions
    */

    // update the baseURI of all tokens
    // initially to prevent rarity sniping all tokens metadata will come from a cnetralized domain
    // and we'll upddate this to IPFS once the mint finishes
    function setBaseURI(string calldata uri) external onlyOwner {
        __baseURI = uri;
    }

    // upcate the locked baseURI just like the other one
    function setLockedBaseURI(string calldata uri) external onlyOwner {
        __lockedBaseURI = uri;
    }

    // allow us to change the mint date for testing and incase of error 
    function setStartingTime(uint256 newStartTime) external onlyOwner {       
        startingTime = newStartTime;
    }

    // allow us to change the mint date for testing and incase of error 
    function setArtStartingTime(uint256 newArtStartTime) external onlyOwner {       
        artStartTime = newArtStartTime;
    }

    // Withdraw funds in contract
    function withdraw(uint _amount) external onlyOwner {
        // for security, can only be sent to owner (or should we allow anyone to withdraw?)
        address payable receiver = payable(owner());
        receiver.transfer(_amount);
    }

    // value / 10000 (basis points)
    function updateDefaultRoyalty(address newAddr, uint96 newPerc) external onlyOwner {
        defaultRoyaltyInfo.receiver = newAddr;
        defaultRoyaltyInfo.royaltyFraction = newPerc;
    }

    function updateRoyaltyInfoForToken(uint256 _tokenId, address _receiver, uint96 _amountBasis) external onlyOwner {
        require(_amountBasis <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(_receiver != address(0), "ERC2981: invalid parameters");

        _tokenRoyaltyInfo[_tokenId] = RoyaltyInfo(_receiver, _amountBasis);
    }

    /*
    *   Helper Functions
    */
    function _baseURI() internal view virtual override returns (string memory) {
        return __baseURI;
    }

    function _lockedBaseURI() internal view returns (string memory) {
        return __lockedBaseURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721) returns (bool) {
        return ERC721.supportsInterface(interfaceId);
    }

    // see if minting is still possible
    function _isTokenAvailable() internal view returns (bool) {
        return _tokensMinted.current() < MAX_SUPPLY;
    }

    // used for royalty fraction
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    } 

    /*
    *   Public View Function
    */
    
    // concatenate the baseURI with the tokenId
    function tokenURI(uint256 tokenId) public view virtual override returns(string memory) {
        require(_exists(tokenId), "token does not exist");

        if (tokenIdToFrozenForArt[tokenId]) {
            string memory lockedBaseURI = _lockedBaseURI();
            return bytes(lockedBaseURI).length > 0 ? string(abi.encodePacked(lockedBaseURI, Strings.toString(tokenIdToMetadataId[tokenId]))) : "";
        }

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenIdToMetadataId[tokenId]))) : "";
    }

    function getTotalMinted() external view returns (uint256) {
        return _tokensMinted.current();
    }

    function getTotalRerolls() external view returns (uint256) {
        return _tokensRerolled.current();
    }

    // tokenURIs increment with both mints and rerolls
    // we use this function in our backend api to avoid trait sniping
    function getTotalTokenURIs() external view returns (uint256) {
        return _tokensRerolled.current() + _tokensMinted.current();
    }

    function tokenHasRequested3DArt(uint256 tokenId) external view returns (bool) {
        return tokenIdToFrozenForArt[tokenId];
    }

    function getRemainingRerollsForAddress(address addr) external view returns (uint16) {
        return remainingRerolls[addr];
    }

    function getRemainingPreReleaseMintsForAddress(address addr) external view returns (uint16) {
        return remainingPreReleaseMints[addr];
    }

    function getMetadataIdForTokenId(uint256 tokenId) external view returns (uint256) {
        return tokenIdToMetadataId[tokenId];
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
            RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

            if (royalty.receiver == address(0)) {
                royalty = defaultRoyaltyInfo;
            }

            uint256 _royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();
            return (royalty.receiver, _royaltyAmount);
    }

    /*
    *   Public Functions
    */

    // Used to request a 3D body for your voxmon
    // Freezes transfers re-rolling a voxmon
    function request3DArt(uint256 tokenId) external {
        require(block.timestamp >= artStartTime, "you cannot freeze your Voxmon yet");
        require(ownerOf(tokenId) == msg.sender, "you must own this token to request Art");
        require(tokenIdToFrozenForArt[tokenId] == false, "art has already been requested for that Voxmon");
        tokenIdToFrozenForArt[tokenId] = true;

        emit artRequestedEvent(msg.sender, tokenId);
    }

    /*
    *   Payable Functions 
    */  
    
    // Mint a Voxmon
    // Cost is 0.07 ether
    function mint(address recipient) payable public returns (uint256) {
        require(_isTokenAvailable(), "max live supply reached, to get a new Voxmon you\'ll need to reroll an old one");
        require(msg.value >= MINT_COST, "not enough ether, minting costs 0.07 ether");
        require(block.timestamp >= startingTime, "public mint hasn\'t started yet");

        _tokensMinted.increment();
        
        uint256 newTokenId = _tokensMinted.current();
        uint256 metadataId = _tokensMinted.current() + _tokensRerolled.current();
        
        _mint(recipient, newTokenId);
        tokenIdToMetadataId[newTokenId] = metadataId;

        emit mintEvent(recipient, newTokenId, metadataId);

        return newTokenId;
    }

    // Mint multiple Voxmon
    // Cost is 0.07 ether per Voxmon
    function mint(address recipient, uint256 numberToMint) payable public returns (uint256[] memory) {
        require(numberToMint > 0);
        require(numberToMint <= 10, "max 10 voxmons per transaction");
        require(msg.value >= MINT_COST * numberToMint);

        uint256[] memory tokenIdsMinted = new uint256[](numberToMint);

        for(uint i = 0; i < numberToMint; i++) {
            tokenIdsMinted[i] = mint(recipient);
        }

        return tokenIdsMinted;
    }

    // Mint a free Voxmon
    function preReleaseMint(address recipient) public returns (uint256) {
        require(remainingPreReleaseMints[msg.sender] > 0, "you have 0 remaining pre-release mints");
        remainingPreReleaseMints[msg.sender] = remainingPreReleaseMints[msg.sender] - 1;

        require(_isTokenAvailable(), "max live supply reached, to get a new Voxmon you\'ll need to reroll an old one");

        _tokensMinted.increment();
        
        uint256 newTokenId = _tokensMinted.current();
        uint256 metadataId = _tokensMinted.current() + _tokensRerolled.current();
        
        _mint(recipient, newTokenId);
        tokenIdToMetadataId[newTokenId] = metadataId;

        emit mintEvent(recipient, newTokenId, metadataId);

        return newTokenId;
    }

    // Mint multiple free Voxmon
    function preReleaseMint(address recipient, uint256 numberToMint) public returns (uint256[] memory) {
        require(remainingPreReleaseMints[msg.sender] >= numberToMint, "You don\'t have enough remaining pre-release mints");

        uint256[] memory tokenIdsMinted = new uint256[](numberToMint);

        for(uint i = 0; i < numberToMint; i++) {
            tokenIdsMinted[i] = preReleaseMint(recipient);
        }

        return tokenIdsMinted;
    }

    // Re-Roll a Voxmon
    // Cost is 0.01 ether 
    function reroll(uint256 tokenId) payable public returns (uint256) {
        require(ownerOf(tokenId) == msg.sender, "you must own this token to reroll");
        require(msg.value >= REROLL_COST, "not enough ether, rerolling costs 0.03 ether");
        require(tokenIdToFrozenForArt[tokenId] == false, "this token is frozen");
        
        _tokensRerolled.increment();
        uint256 newMetadataId = _tokensMinted.current() + _tokensRerolled.current();

        tokenIdToMetadataId[tokenId] = newMetadataId;
        
        emit rerollEvent(msg.sender, tokenId, newMetadataId);

        return newMetadataId;
    }

    // Re-Roll a Voxmon
    // Cost is 0.01 ether 
    function freeReroll(uint256 tokenId) public returns (uint256) {
        require(remainingRerolls[msg.sender] > 0, "you have 0 remaining free rerolls");
        remainingRerolls[msg.sender] = remainingRerolls[msg.sender] - 1;

        require(ownerOf(tokenId) == msg.sender, "you must own the token to reroll");
        require(tokenIdToFrozenForArt[tokenId] == false, "this token is frozen");
        
        _tokensRerolled.increment();
        uint256 newMetadataId = _tokensMinted.current() + _tokensRerolled.current();

        tokenIdToMetadataId[tokenId] = newMetadataId;
        
        emit rerollEvent(msg.sender, tokenId, newMetadataId);

        return newMetadataId;
    }
}