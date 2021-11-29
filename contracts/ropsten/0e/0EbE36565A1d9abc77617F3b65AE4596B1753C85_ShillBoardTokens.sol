// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';

contract ShillBoardTokens is ERC721, Pausable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter public _tokenIdCounter;

    // Events
    event Mint(address indexed _address, uint256 tokenId);

    // Constructor
    constructor() ERC721('ShillBoard - 5 Seconds', 'SBT') {
        for (uint256 i = 0; i < FOUNDERS_RESERVE; i++) {
            _safeMint(msg.sender);
        }
    }

    // Supply
    uint256 FOUNDERS_RESERVE = 12;
    uint256 public MAX_SUPPLY = 720;

    // URI TODO: CHANGE URI!
    string public _baseTokenURI = 'https://nonfungible.tools/api/metadata/';

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    // Price
    uint256 public _price = 0.1 ether;

    function setPrice(uint256 price) public onlyOwner {
        _price = price;
    }

    // Whitelist
    // change to private
    mapping(address => uint8) public _allowList;

    function setAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _allowList[addresses[i]] = 6;
        }
    }

    // Mint status
    bool public preMintIsActive = false;
    bool public openMintIsActive = false;

    function setPreMintActive(bool _preMintIsActive) external onlyOwner {
        preMintIsActive = _preMintIsActive;
    }

    function setOpenMintActive(bool _openMintIsActive) external onlyOwner {
        openMintIsActive = _openMintIsActive;
    }

    // Mint action
    function preMint(address _to, uint8 numberOfTokens)
        public
        payable
        whenNotPaused
    {
        require(preMintIsActive, 'Premint is not active');
        require(
            _price * numberOfTokens == msg.value,
            'Ether value sent is not correct'
        );
        require(
            _tokenIdCounter.current() + numberOfTokens <= MAX_SUPPLY,
            "Can't mint over supply limit"
        );
        require(
            numberOfTokens <= _allowList[_to],
            'Exceeded max available to purchase'
        );

        _allowList[_to] -= numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _tokenIdCounter.increment();
            _safeMint(_to, _tokenIdCounter.current());
            emit Mint(_to, _tokenIdCounter.current());
        }
    }

    function mint(address _to, uint8 numberOfTokens)
        public
        payable
        whenNotPaused
    {
        require(openMintIsActive, 'Open mint is not active');
        require(
            _price * numberOfTokens == msg.value,
            'Ether value sent is not correct'
        );
        require(
            _tokenIdCounter.current() + numberOfTokens <= MAX_SUPPLY,
            "Can't mint over supply limit"
        );
        require(numberOfTokens <= 6, 'Cannot mint more than 6 NFTs');

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _tokenIdCounter.increment();
            _safeMint(_to, _tokenIdCounter.current());
            emit Mint(_to, _tokenIdCounter.current());
        }
    }

    function _safeMint(address to) public onlyOwner {
        _tokenIdCounter.increment();
        _safeMint(to, _tokenIdCounter.current());
    }

    // (Un)pause Contract
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    // Withdraw
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;

        payable(msg.sender).transfer(balance);
    }
}