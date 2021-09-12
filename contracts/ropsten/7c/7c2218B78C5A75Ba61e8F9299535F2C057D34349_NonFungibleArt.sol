// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract NonFungibleArt is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_NFTS = 5222;
    uint256 public constant PRICE = 0.05 ether;
    uint256 public constant PRESALE_MAX_MINT = 1;
    uint256 public constant MAX_PER_MINT = 2;
    uint256 public constant MAX_PER_WALLET = 50;
    uint256 public constant RESERVED_NFTS = 200;
    address public constant founder1Address = 0x28662a2d3caA27f65DDc5aEf27f2aB2B819E56D6;
    address public constant founder2Address = 0xA6b42f9D0eb06AA40FcAa2E368cED1A8aa6761b5; /* to be changed */

    uint256 public reservedClaimed;

    uint256 public nftsMinted;

    string public baseTokenURI;

    bool public publicSaleStarted;
    bool public presaleStarted;

    mapping(address => bool) private _presaleEligible;
    mapping(address => uint256) private _totalClaimed;

    event BaseURIChanged(string baseURI);
    event PresaleMint(address minter, uint256 amount);
    event PublicSaleMint(address minter, uint256 amount);

    modifier whenPresaleStarted() {
        require(presaleStarted, "Presale has not started");
        _;
    }

    modifier whenPublicSaleStarted() {
        require(publicSaleStarted, "Public sale has not started");
        _;
    }

    constructor(string memory baseURI) ERC721("NonFungibleArt", "ART") {
        baseTokenURI = baseURI;
    }

    function claimReserved(address recipient, uint256 amount) external onlyOwner {
        require(reservedClaimed != RESERVED_NFTS, "Already have claimed all reserved tokens");
        require(reservedClaimed + amount <= RESERVED_NFTS, "Minting would exceed max reserved tokens");
        require(recipient != address(0), "Cannot add null address");
        require(totalSupply() < MAX_NFTS, "All tokens have been minted");
        require(totalSupply() + amount <= MAX_NFTS, "Minting would exceed max supply");

        uint256 _nextTokenId = nftsMinted + 1;

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(recipient, _nextTokenId + i);
        }
        nftsMinted += amount;
        reservedClaimed += amount;
    }

    function addToPresale(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Cannot add null address");

            _presaleEligible[addresses[i]] = true;

            _totalClaimed[addresses[i]] > 0 ? _totalClaimed[addresses[i]] : 0;
        }
    }

    function checkPresaleEligiblity(address addr) external view returns (bool) {
        return _presaleEligible[addr];
    }

    function amountClaimedBy(address owner) external view returns (uint256) {
        require(owner != address(0), "Cannot add null address");

        return _totalClaimed[owner];
    }

    function mintPresale(uint256 amount) external payable whenPresaleStarted {
        require(_presaleEligible[msg.sender], "You are not eligible for the presale");
        require(totalSupply() < MAX_NFTS, "All tokens have been minted");
        require(amount <= PRESALE_MAX_MINT, "Cannot purchase this many tokens during presale");
        require(totalSupply() + amount <= MAX_NFTS, "Minting would exceed max supply");
        require(_totalClaimed[msg.sender] + amount <= PRESALE_MAX_MINT, "Purchase exceeds max allowed");
        require(amount > 0, "Must mint at least one NFT");
        require(PRICE * amount == msg.value, "ETH amount is incorrect");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = nftsMinted + 1;

            nftsMinted += 1;
            _totalClaimed[msg.sender] += 1;
            _safeMint(msg.sender, tokenId);
        }

        emit PresaleMint(msg.sender, amount);
    }

    function mint(uint256 amount) external payable whenPublicSaleStarted {
        require(totalSupply() < MAX_NFTS, "All tokens have been minted");
        require(amount <= MAX_PER_MINT, "Cannot purchase this many tokens in a transaction");
        require(totalSupply() + amount <= MAX_NFTS, "Minting would exceed max supply");
        require(_totalClaimed[msg.sender] + amount <= MAX_PER_WALLET, "Purchase exceeds max allowed per address");
        require(amount > 0, "Must mint at least one NFT");
        require(PRICE * amount == msg.value, "ETH amount is incorrect");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = nftsMinted + 1;

            nftsMinted += 1;
            _totalClaimed[msg.sender] += 1;
            _safeMint(msg.sender, tokenId);
        }

        emit PublicSaleMint(msg.sender, amount);
    }

    function togglePresaleStarted() external onlyOwner {
        presaleStarted = !presaleStarted;
    }

    function togglePublicSaleStarted() external onlyOwner {
        publicSaleStarted = !publicSaleStarted;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
        emit BaseURIChanged(baseURI);
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficent balance");
        _widthdraw(founder1Address, ((balance * 50) / 100));
        _widthdraw(founder2Address, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{ value: _amount }("");
        require(success, "Failed to widthdraw Ether");
    }
}