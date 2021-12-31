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

    constructor() ERC721("Transcript", "TRN") {}  // smart contract's name, smart contract's symbol

    // updates the mapping with strings that have been used
    function updateStrings(string memory str) private {
        usedStrings[str] = true;
    }

    // checks to see if a string has been minted already
    function checkIfUsed(string memory str) public view returns (bool) {  // view means that we can look at the value of a state variable in the contract
        return usedStrings[str];  // tell us if the string is in the mapping (true if there, false if not)
    }

    function append(string memory a, string memory b, string memory c) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    // actually mint the string
    function mintNFT(string memory str) public returns (uint256) {
        //require(checkIfUsed(str) == false, "this string has already been minted");  // check to make sure the string is unique
        updateStrings(str);  // add string to the used list

        _tokenIds.increment();  // increment the tokenID

        uint256 newItemId = _tokenIds.current();  // get the current itemID
        _mint(msg.sender, newItemId);  // mint the nft and send it to the person who called the contract
        _setTokenURI(newItemId, Base64.encode(bytes(append('{\n\t"string": "', str, '"\n}'))));  // set the uri according to the token ID

        return newItemId;
    }
}