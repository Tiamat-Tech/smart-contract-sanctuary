//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
pragma solidity ^0.8.0;

contract Sentence is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _sentenceIds;
    mapping(uint256 => string) public sentences;

    constructor() ERC721("Sentence", "SNT") {}

    function newSentence(string memory _sentence) public returns (uint256) {
        _sentenceIds.increment();

        uint256 newSentenceId = _sentenceIds.current();
        _mint(msg.sender, newSentenceId);
        console.log(newSentenceId);
        sentences[newSentenceId] = _sentence;
        //, tokenURI);

        return newSentenceId;
    }
}

/*
contract NftBook {
    //was Greeter
    string private sentence;

    constructor(string memory _sentence) {
        console.log("Deploying a NftBook with sentence:", _sentence);
        sentence = _sentence;
    }

    function getSentence() public view returns (string memory) {
        return sentence;
    }

    function setSentence(string memory _sentence) public {
        console.log("Changing sentence from '%s' to '%s'", sentence, _sentence);
        sentence = _sentence;
    }
}
*/