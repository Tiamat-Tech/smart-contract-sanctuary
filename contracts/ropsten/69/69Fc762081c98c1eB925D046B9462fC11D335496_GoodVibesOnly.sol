pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GoodVibesOnly is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    string _baseUri;
    string _contractUri;
    
    uint public constant MAX_SUPPLY = 5000;
    uint public price = 40000000000000000; // .04
    uint public maxFreeMint = 500;
    uint public maxFreeMintPerWallet = 20;
    uint public MAX_PER_TSX = 50;
    bool public isSalesActive = false;
    
    mapping(address => uint) public addressToFreeMinted;

    constructor() ERC721("GoodVibesOnly", "GOODVIBES") {
        _contractUri = "";
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }
    
    function freeMint() external {
        require(isSalesActive, "The sale is not active");
        require(totalSupply() < maxFreeMint, "No free mints are remaining");
        require(addressToFreeMinted[msg.sender] < maxFreeMintPerWallet, "You can only free mint a maximum of 20 times");
        
        addressToFreeMinted[msg.sender]++;
        safeMint(msg.sender);
    }
    
    function mint(uint quantity) external payable {
        require(isSalesActive, "The sale is not active");
        require(quantity <= MAX_PER_TSX, "Number of mints this tsx exceeds the maximum you ape. Mint less.");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Sold out. Good vibes are only on secondary now.");
        require(msg.value >= price * quantity, "Not enough ether.");
        
        for (uint i = 0; i < quantity; i++) {
            safeMint(msg.sender);
        }
    }

    function safeMint(address to) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }
    
    function totalSupply() public view returns (uint) {
        return _tokenIdCounter.current();
    }
    
    function contractURI() public view returns (string memory) {
        return _contractUri;
    }
    
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseUri = newBaseURI;
    }
    
    function setContractURI(string memory newContractURI) external onlyOwner {
        _contractUri = newContractURI;
    }
    
    function toggleSales() external onlyOwner {
        isSalesActive = !isSalesActive;
    }
    
    function setPrice(uint newPrice) external onlyOwner {
        price = newPrice;
    }
    
    function withdrawAll() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}