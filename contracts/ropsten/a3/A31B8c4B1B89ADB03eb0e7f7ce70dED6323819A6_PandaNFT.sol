//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract PandaNFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    using SafeMath for uint256;

    uint256 public constant tokenPrice = 20000000000000000; //0.02 ETH
    uint256 public MAX_TOKEN=24;
    string public _baseURIextended;

    constructor() ERC721("PandaNFT", "PANDANFT") {}

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    /* Set proper BaseURI */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIextended = baseURI_;

    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    /* Mint token */
    function mintToken(uint numberOfTokens) public payable {
        require(totalSupply().add(numberOfTokens) <= MAX_TOKEN, "Would exceed the available number of tokens");
        require(tokenPrice.mul(numberOfTokens) <= msg.value, "Ether value is not enough");

        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_TOKEN) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }
}