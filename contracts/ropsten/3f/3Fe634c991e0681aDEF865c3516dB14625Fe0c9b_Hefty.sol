// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Hefty is ERC721Enumerable, Ownable{
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // constants
    uint256 constant MAX_ELEMENTS = 10000;
    uint256 constant PRESALE_PURCHASE_LIMIT = 3;
    uint256 constant STAGE1_PRICE = 0.05 ether;       // price for pre-sale
    uint256 constant STAGE2_PRICE = 0.08 ether;
    uint256 constant PRESALE_LIFETIME = 48 hours;
    enum STAGE { INITIAL, PRE_SALE, PUBLIC_SALE }

    // state variable
    STAGE public CURRENT_STAGE = STAGE.INITIAL;
    bool public MINTING_PAUSED = true;
    uint256 public PRESALE_STARTED_TIME = block.timestamp;
    string public baseTokenURI;
    string public _contractURI = "";

    Counters.Counter private _tokenIdTracker;

    // whitelist variable
    mapping(address => bool) private whiteList;        // for pre-sale of friends
    
    mapping(uint256 => address) private claimedList;
    mapping(address => uint256) private _allowListClaimed;

    constructor() ERC721("Hefty", "Hefty"){
    }

    function setPauseMinting(bool _pause) public onlyOwner{
        MINTING_PAUSED = _pause;
    }

    function preSale(uint256 numberOfTokens) external payable {
        require(!MINTING_PAUSED, "Minting is not active");
        require(CURRENT_STAGE == STAGE.PRE_SALE, "Current stage should be PRE_SALE");
        require(block.timestamp - PRESALE_STARTED_TIME < PRESALE_LIFETIME, "Life time for PRE_SALE is 48 hours.");
        require(whiteList[msg.sender], "You are not on the whitelist");
        require(totalSupply() < MAX_ELEMENTS, 'All tokens have been minted');
        require(totalSupply() + numberOfTokens < MAX_ELEMENTS, 'Purchase would exceed max supply');
        require(_allowListClaimed[msg.sender] + numberOfTokens <= PRESALE_PURCHASE_LIMIT, 'Purchase exceeds max allowed');
        require(STAGE1_PRICE * numberOfTokens <= msg.value, 'ETH amount is not sufficient');

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _tokenIdTracker.increment();

            claimedList[_tokenIdTracker.current()] = msg.sender; // should be checked
            _allowListClaimed[msg.sender] += 1;
            _safeMint(msg.sender, _tokenIdTracker.current());
        }
    }

    function publicMint(uint256 numberOfTokens) external payable {
        require(!MINTING_PAUSED, "Minting is not active");
        require(CURRENT_STAGE == STAGE.PUBLIC_SALE, "Current stage should be PUBLIC_SALE");
        require(totalSupply() < MAX_ELEMENTS, 'All tokens have been minted');
        require(totalSupply() + numberOfTokens < MAX_ELEMENTS, 'Purchase would exceed max supply');
        require(STAGE2_PRICE * numberOfTokens <= msg.value, 'ETH amount is not sufficient');

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _tokenIdTracker.increment();

            claimedList[_tokenIdTracker.current()] = msg.sender; // should be checked
            _safeMint(msg.sender, _tokenIdTracker.current());
        }
    }

    function setWhiteList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add the null address");
            whiteList[addresses[i]] = true;
        }
    }

    function setStage(uint256 _stage) external onlyOwner {
        CURRENT_STAGE = STAGE(_stage);

        if (CURRENT_STAGE == STAGE.PRE_SALE) {
          PRESALE_STARTED_TIME = block.timestamp;
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        payable(msg.sender).transfer(balance);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
}