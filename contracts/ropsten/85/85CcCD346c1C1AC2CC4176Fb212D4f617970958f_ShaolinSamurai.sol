// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

interface PaymentSplitter {
    function pay(uint id) external payable;
}

contract ShaolinSamurai is ERC721, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    PaymentSplitter _paymentSplitter = PaymentSplitter(0x5A9323eF2160121F651F73884B624f131A442158);

    Counters.Counter private _tokenIdCounter;
    string _baseUri;
    uint _splitterId;
    
    uint public constant MAX_SUPPLY = 8888;
    uint public price = 0.0888 ether;
    uint public maxFreeMint = 5;
    uint public maxFreeMintPerWallet = 5;
    bool public isSalesActive = false;
    
    mapping(address => uint) public addressToFreeMinted;

    constructor() ERC721("Shaolin Samurai", "SHAOSAMURAI") { }

    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }
    
    function freeMint() external {
        require(isSalesActive, "sale is not active");
        require(totalSupply() < maxFreeMint, "theres no free mints remaining");
        require(addressToFreeMinted[msg.sender] < maxFreeMintPerWallet, "caller already minted for free");
        
        addressToFreeMinted[msg.sender]++;
        safeMint(msg.sender);
    }
    
    function mint(uint quantity) external payable {
        require(isSalesActive, "sale is not active");
        require(quantity <= 10, "max mints per transaction exceeded");
        require(totalSupply() + quantity <= MAX_SUPPLY, "sold out");
        require(msg.value >= price * quantity, "ether send is under price");
        
        for (uint i = 0; i < quantity; i++) {
            safeMint(msg.sender);
        }

        _paymentSplitter.pay{value: address(this).balance}(_splitterId);
    }

    function safeMint(address to) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }
    
    function totalSupply() public view returns (uint) {
        return _tokenIdCounter.current();
    }
    
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseUri = newBaseURI;
    }
    
    function toggleSales() external onlyOwner {
        isSalesActive = !isSalesActive;
    }
    
    function setPrice(uint newPrice) external onlyOwner {
        price = newPrice;
    }
    
    function setSplitterId(uint splitterId_) public onlyOwner {
        _splitterId = splitterId_;
    }
}