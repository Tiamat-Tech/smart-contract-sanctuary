pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract BTFDchads is ERC721Enumerable, Ownable {  
    using Address for address;
    
    // Starting and stopping sale
    bool public saleActive = false;

    // WL function
    bool public isAllowListActive = false;

    // Price of each token
    uint256 public price = 0.045 ether;
    uint256 public MAX_MINT_PER_TRANSACTION = 20;

    // Maximum limit of tokens that can ever exist
    uint256 constant MAX_SUPPLY = 6969;
    
    // Max sales
    uint256 public MAX_FOR_SALE = MAX_SUPPLY;

    // The base link that leads to the jpeg of the token
    string public baseTokenURI;
    
    constructor (string memory newBaseURI) ERC721 ("BTFD Chads", "BTFD Chads") {
        setBaseURI(newBaseURI);
    }


    // Override so the openzeppelin tokenURI() method will use this method to create the full tokenURI instead
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    // See which address owns which tokens
    function tokensOfOwner(address addr) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(addr);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(addr, i);
        }
        return tokensId;
    }
    
    // Get price by amount
    function getPrice(uint256 _amount) public view returns (uint256) {
        return price * _amount;
    }

    // Standard mint function
    function mintToken(uint256 _amount) public payable {
        uint256 supply = totalSupply();
        require( saleActive, "Sale is not active" );
        require( _amount > 0 && _amount <= MAX_MINT_PER_TRANSACTION, "Can only mint between 1 and 20 tokens at once" );
        require( supply + _amount <= MAX_FOR_SALE, "Can't mint more than MAX_SUPPLY - reserved" );
        require( msg.value == getPrice(_amount), "Wrong amount of ETH sent" );
        for(uint256 i; i < _amount; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    // Start and stop sale
    function setSaleActive(bool val) public onlyOwner {
        saleActive = val;
    }

    // Set new baseURI
    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    // Set a different price in case ETH changes drastically
    function setPrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }

    // Withdraw funds from contract 
        function withdraw() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}