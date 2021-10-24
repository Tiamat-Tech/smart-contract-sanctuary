// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Essences is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint public constant MAX_SUPPLY = 1000;
    uint public constant MINT_PRICE = 50000000000000000;

    uint public constant MAX_SUPPLY_PER_TXN = 10;

    bool public mintIsActive = false;
    bool public whitelistIsActive = false;
    bool public mintingIsActive = false;
    string public baseTokenURI;


    //Whitelist Minting Constants
    mapping(address => bool) public whiteList;

    constructor(string memory baseURI) ERC721("FountainOfLife", "Essence") {
        setBaseURI(baseURI);
    }

    //Whitelist Logic
    function mintFromWhitelist() public payable {
        require(whitelistIsActive, "Must be active to mint Essences");
        require(totalSupply().add(1) <= MAX_SUPPLY, "Mint would exceed max supply of Essences");
        require(MINT_PRICE.mul(1) <= msg.value, "Ether value sent is not correct");
        require(isWhiteList(msg.sender), "Not on whitelist or whitelist used");

        whiteList[msg.sender] = false;
        uint256 mintIndex = totalSupply();
        _safeMint(msg.sender, mintIndex);
    }

    function isWhiteList(address addr) public view returns (bool) {
        return whiteList[addr];
    }

    function addToWhiteList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");
            require(!whiteList[entry], "DUPLICATE_ENTRY");

            whiteList[entry] = true;
        }   
    }

    //Function for the main sale. Can mint 8 at most in one txn 
    //Can mint when sale is active and totalSupply < 1000
    function mintEssences(uint numberOfEssences) public payable {
        require(mintIsActive, "Must be active to mint Essences");
        require(numberOfEssences > 0 && numberOfEssences <= MAX_SUPPLY_PER_TXN, "Can only mint between 0 and 10 Essences at a time");
        require(totalSupply().add(numberOfEssences) <= MAX_SUPPLY, "Mint would exceed max supply of Essences");
        require(MINT_PRICE.mul(numberOfEssences) <= msg.value, "Ether value sent is not correct");

        for(uint i = 0; i < numberOfEssences; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }
    //Only owner actions
    //Reserve for team and partnerships
    function reserveEssences(address addr, uint numberOfEssences) public onlyOwner {
        require(totalSupply().add(numberOfEssences) <= MAX_SUPPLY, "Mint would exceed max supply of Essences");
        require(!mintIsActive, 'Too late to reserve');
        for (uint i = 0; i < numberOfEssences; i++) {
            uint mintIndex = totalSupply();
            _safeMint(addr, mintIndex);
        }
    }

    function reserveMultipleEssences(address[] calldata entries) public onlyOwner {
        require(totalSupply().add(entries.length) <= MAX_SUPPLY, "Mint would exceed max supply of Essences");
        require(!mintIsActive, 'Too late to reserve');
        for (uint i = 0; i < entries.length; i++) {
            address addr = entries[i];
            uint mintIndex = totalSupply();
            _safeMint(addr, mintIndex);
        }
    }

    //Turn sale active
    function flipMintState() public onlyOwner {
        mintIsActive = !mintIsActive;
    }

    //Turn sale active
    function flipwhitelistState() public onlyOwner {
        whitelistIsActive = !whitelistIsActive;
    }

    // internal function override
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    // set baseURI
    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    //Witdraw funds
    function withdrawAll() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

}