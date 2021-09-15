// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MyNFT is ERC721Enumerable, Ownable {

    uint256 public constant PRICE = 0.0000000001 ether;
    uint256 public constant MAX_EDEN = 100000;
    uint256 public constant MAX_PER_MINT = 20;

    address public constant founderAddress = 0x4505AD2446fbe06ed31c361AE76fB3fd71bCf7E0;

    bool public publicSaleStarted;

    mapping(address => bool) private _EligiblePool;
    mapping(address => uint256) private _totalClaimed;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("EdenCoin", "EDEN") {}

    modifier whenPublicSaleStarted() {
        require(publicSaleStarted, "Public sale has not started");
        _;
    }

    function checkEligiblity(address addr) external view returns (bool) {
        return _EligiblePool[addr];
    }

    function addToPool(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Cannot add null address");

            _EligiblePool[addresses[i]] = true;
        }
    }

    function amountClaimedBy(address owner) external view returns (uint256) {
        require(owner != address(0), "Cannot add null address");

        return _totalClaimed[owner];
    }

    function mintNFT(uint256 quantity) external payable whenPublicSaleStarted
    {
        uint256 price = getPrice(quantity);
        // Ensure enough ETH
        //require(_EligiblePool[msg.sender], "You are not eligible for this contract");
        require(totalSupply() < MAX_EDEN, "All tokens have been minted");
        require(quantity <= MAX_PER_MINT, "Cannot purchase this many tokens in a transaction");
        require(quantity > 0, "Must mint at least one EDEN");
        require(price == msg.value, "ETH amount is incorrect");

        for(uint256 i=0; i<quantity; i++)
        {
            _tokenIds.increment();

            uint256 newItemId = _tokenIds.current();
            _safeMint(msg.sender, newItemId);
            _totalClaimed[msg.sender] += 1;
        }
    }

    function getPrice(uint256 quantity) pure public returns (uint256)
    {
        return quantity * PRICE;
    }

    function togglePublicSaleStarted() external onlyOwner {
        publicSaleStarted = !publicSaleStarted;
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficent balance");
        _widthdraw(founderAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{ value: _amount }("");
        require(success, "Failed to widthdraw Ether");
    }

}