pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";

contract Otomotors is ERC721Enumerable {
    // using Counters for Counters.Counter;
    // Counters.Counter private _tokenIds;
    
    uint256 public startingIndexBlock; // TODO
    uint256 public startingIndex; // TODO
    uint256 public constant mintPrice = 50000000000000000; //0.05 ETH
    uint public constant maxPurchase = 20;
    uint256 public MAX_OTOMOTORS = 10000;

    bool public saleIsActive = true; // TODO

    constructor() ERC721("Otomotors", "OTO") {}

    function mint(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint Otomotor");
        require(numberOfTokens <= maxPurchase, "Can only mint 20 tokens at a time");
        require(totalSupply() + numberOfTokens <= MAX_OTOMOTORS, "Purchase would exceed max supply of Otomotors");
        require(mintPrice * numberOfTokens <= msg.value, "Ether value sent is not correct");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_OTOMOTORS) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }
}