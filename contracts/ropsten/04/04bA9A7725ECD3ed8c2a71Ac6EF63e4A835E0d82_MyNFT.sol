//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public mintPrice = 0.1 ether;

    bool public open = false;

    string public defaultURI = "https://www.nftrepainted.com/token/";

    uint256 public MAX_SUPPLY = 200;

    constructor() public ERC721("MyNFT", "NFT") {
        ownerMint(20);
    }

    modifier isOpen() {
        require(open, "Contract is closed right now");
        _;
    }

    function setOpen(bool shouldOpen) external onlyOwner {
        open = shouldOpen;
    }

    function mint(uint256 quantity) public payable isOpen {
        require(quantity > 0, "Quantity must be at least 1");

        // Limit buys
        if (quantity > 100) {
            quantity = 100;
        }

        // Limit buys that exceed MAX_SUPPLY
        if (quantity + totalSupply() > MAX_SUPPLY) {
            quantity = MAX_SUPPLY - totalSupply();
        }

        uint256 price = getPrice(quantity);

        // Ensure enough ETH
        require(msg.value >= price, "Not enough ETH sent");

        for (uint256 i = 0; i < quantity; i++) {
            _mintInternal(msg.sender);
        }

        // Return any remaining ether after the buy
        uint256 remaining = msg.value - price;

        if (remaining > 0) {
            (bool success, ) = msg.sender.call{value: remaining}("");
            require(success);
        }
    }

    function getPrice(uint256 quantity) public view returns (uint256) {
        require(quantity <= MAX_SUPPLY);
        return quantity * mintPrice;
    }

    function totalSupply() public view returns (uint256) {
        // the current tokenId is the last one we have minted, so thats how many we have
        return _tokenIds.current();
    }

    function withdraw() public onlyOwner {
        // get the amount of Ether stored in this contract
        uint amount = address(this).balance;

        // send all Ether to owner
        // Owner can receive Ether since the address of owner is payable
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    // Function to deposit Ether into this contract.
    // Call this function along with some Ether.
    // The balance of this contract will be automatically updated.
    function deposit() public payable {}

    function _baseURI() internal view virtual override returns (string memory) {
        return defaultURI;
    }

    // Private Methods
    function _mintInternal(address recipient) private {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
    }

    // Admin methods
    function ownerMint(uint256 quantity) public onlyOwner {
        for (uint256 i = 0; i < quantity; i++) {
            _mintInternal(msg.sender);
        }
    }

    function setMintPrice(uint256 price) public onlyOwner {
        mintPrice = price;
    }

    function setMaxSupply(uint256 newSupply) public onlyOwner {
        MAX_SUPPLY = newSupply;
    }

    function setDefaultURI(string memory newDefaultURI) public onlyOwner {
        defaultURI = newDefaultURI;
    }
}