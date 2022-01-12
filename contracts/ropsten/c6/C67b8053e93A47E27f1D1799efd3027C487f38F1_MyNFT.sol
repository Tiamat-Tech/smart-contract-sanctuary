//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";  // implementation of the erc721 standard, string nft inherits from this
import "@openzeppelin/contracts/utils/Counters.sol";  // counters that can only be incremented or decremented by 1
import "@openzeppelin/contracts/access/Ownable.sol";  // sets up access control so that only the owner can interact
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "base64-sol/base64.sol";  // gets enoding functions

contract MyNFT is ERC721URIStorage {
    using Counters for Counters.Counter;  // set counter object path
    Counters.Counter private _tokenIds;  // initialize counter object
    mapping(string => bool) private usedStrings;  // initialize mapping for keeping track of unique strings
    mapping(uint256 => string) private tokenIDtoString;  // initialize mapping of token ID to string
    uint256 cost = 0.0025e18;  // set the minting fee

    constructor() ERC721("Transcript", "TRN") {}  // smart contract's name, smart contract's symbol

    // updates the mapping with strings that have been used
    function updateStrings(string memory str) private {
        usedStrings[str] = true;
    }

    // checks to see if a string has been minted already
    function checkIfUsed(string memory str) public view returns (bool) {  // view means that we can look at the value of a state variable in the contract
        return usedStrings[str];  // tell us if the string is in the mapping (true if there, false if not)
    }

    // given tokenID, returns the string associated with that tokenID
    function getString(uint256 tokenId) public view returns (string memory) {
        return tokenIDtoString[tokenId];
    }

    // triple input concatenation
    function append(string memory a, string memory b, string memory c) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    // double input concatenation
    function append(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    // override the default function and wrap the string in a nice little base64'd json format
    function tokenURI(uint256 id) override public view returns (string memory) {
        string memory base = 'data:application/json;base64,';
        string memory json = append('{\n\t"name": "', tokenIDtoString[id], '"\n}');

        return append(base, Base64.encode(bytes(json)));
    }

    // actually mint the string
    function mintNFT(string memory str) public payable returns (uint256) {
        uint256 amt = msg.value;
        require(amt >= cost, "payment not sufficient");  // msg.value must be larger than the minting fee

        require(!checkIfUsed(str), "this string has already been minted");  // check to make sure the string is unique
        updateStrings(str);  // add string to the used list

        uint256 newItemId = _tokenIds.current();  // get the current itemID
        _tokenIds.increment();  // increment the tokenID

        tokenIDtoString[newItemId] = str;  // update the mapping
        
        _mint(msg.sender, newItemId);  // mint the nft and send it to the person who called the contract

        return newItemId;
    }
}