// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "hardhat/console.sol";


contract SacredCreatures is ERC721Enumerable, ReentrancyGuard, Ownable  {
    using Counters for Counters.Counter;
    Counters.Counter _tokenIds;

    using SafeMath for uint256;


    uint256 public price = 50000000000000000; //0.05 ETH
    uint256 public priceMintWithName = 75000000000000000; //0.075 ETH
    bool public paused = false; // Enable disable
    uint256 public maxTokens = 10000;


    struct creature {
        string nickname;
        uint256 defense;
        uint256 attack;
        uint256 soul;
        uint256 wisdom;
        string rarity;
        string family;
    }

    struct range {
        uint256 defenseMin;
        uint256 defenseMax;
        uint256 attackMin;
        uint256 attackMax;
        uint256 soulMin;
        uint256 soulMax;
        uint256 wisdomMin;
        uint256 wisdomMax;
    }

    

    mapping(uint256 => creature) public creatures;
    mapping(string => range) public rangesByFamily;

    
    event CreatureCreated(
        string name,
        uint256 tokenId,
        creature creatureCreated
    );
    constructor() ERC721("SacredCreatures", "SacredCreatures") Ownable() {
        rangesByFamily["god"].defenseMin = 20;
        rangesByFamily["god"].defenseMax = 50;
        rangesByFamily["god"].attackMin = 20;
        rangesByFamily["god"].attackMax = 50;
        rangesByFamily["god"].soulMin = 50;
        rangesByFamily["god"].soulMax = 100;
        rangesByFamily["god"].wisdomMin = 50;
        rangesByFamily["god"].wisdomMax = 100;

        rangesByFamily["reincarnate"].defenseMin = 20;
        rangesByFamily["reincarnate"].defenseMax = 50;
        rangesByFamily["reincarnate"].attackMin = 20;
        rangesByFamily["reincarnate"].attackMax = 50;
        rangesByFamily["reincarnate"].soulMin = 50;
        rangesByFamily["reincarnate"].soulMax = 100;
        rangesByFamily["reincarnate"].wisdomMin = 50;
        rangesByFamily["reincarnate"].wisdomMax = 100;

        rangesByFamily["demon"].defenseMin = 20;
        rangesByFamily["demon"].defenseMax = 50;
        rangesByFamily["demon"].attackMin = 20;
        rangesByFamily["demon"].attackMax = 50;
        rangesByFamily["demon"].soulMin = 50;
        rangesByFamily["demon"].soulMax = 100;
        rangesByFamily["demon"].wisdomMin = 50;
        rangesByFamily["demon"].wisdomMax = 100;
        
        rangesByFamily["ai"].defenseMin = 20;
        rangesByFamily["ai"].defenseMax = 50;
        rangesByFamily["ai"].attackMin = 20;
        rangesByFamily["ai"].attackMax = 50;
        rangesByFamily["ai"].soulMin = 50;
        rangesByFamily["ai"].soulMax = 100;
        rangesByFamily["ai"].wisdomMin = 50;
        rangesByFamily["ai"].wisdomMax = 100;

        rangesByFamily["chosenOne"].defenseMin = 20;
        rangesByFamily["chosenOne"].defenseMax = 50;
        rangesByFamily["chosenOne"].attackMin = 20;
        rangesByFamily["chosenOne"].attackMax = 50;
        rangesByFamily["chosenOne"].soulMin = 50;
        rangesByFamily["chosenOne"].soulMax = 100;
        rangesByFamily["chosenOne"].wisdomMin = 50;
        rangesByFamily["chosenOne"].wisdomMax = 100;

        rangesByFamily["wizard"].defenseMin = 20;
        rangesByFamily["wizard"].defenseMax = 50;
        rangesByFamily["wizard"].attackMin = 20;
        rangesByFamily["wizard"].attackMax = 50;
        rangesByFamily["wizard"].soulMin = 50;
        rangesByFamily["wizard"].soulMax = 100;
        rangesByFamily["wizard"].wisdomMin = 50;
        rangesByFamily["wizard"].wisdomMax = 100;

        rangesByFamily["savage"].defenseMin = 20;
        rangesByFamily["savage"].defenseMax = 50;
        rangesByFamily["savage"].attackMin = 20;
        rangesByFamily["savage"].attackMax = 50;
        rangesByFamily["savage"].soulMin = 50;
        rangesByFamily["savage"].soulMax = 100;
        rangesByFamily["savage"].wisdomMin = 50;
        rangesByFamily["savage"].wisdomMax = 100;

    
    }

    // Pause or resume minting
    function flipPause() public onlyOwner {
        paused = !paused;
    }

    // Change the public price of the token
    function setPublicPrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }

    // Change the maximum amount of tokens
    function setMaxtokens(uint256 newMaxtokens) public onlyOwner {
        maxTokens = newMaxtokens;
    }

    // Claim deposited eth
    function ownerWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }


    string[] private families = [       
        "god",
        "demon",
        "chosenOne",
        "reincarnate",
        "wizard",
        "savage",
        "ai"
    ];

    string[] private rarities = [       
        "basic",
        "common",
        "rare",
        "superRare",
        "epic",
        "divine"
    ];
    

    function randomFromString(string memory _salt, uint256 _limit)
        internal
        view
        returns (uint256)
    {
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.number, block.timestamp, _salt)
                )
            ) % _limit;
    }

    // Returns a random item from the list, always the same for the same token ID
    function pluck(uint256 tokenId, string memory keyPrefix, string[] memory sourceArray) internal view returns (string memory) {
        uint256 rand = randomFromString(string(abi.encodePacked(keyPrefix, toString(tokenId))), sourceArray.length);

        return sourceArray[rand];
    }


   
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

   

    function getRarity() internal view returns (string memory) {
        uint256 rarity = randomFromString("rarity", 100);
        
        if (rarity < 40) {
            return "basic";
        } else if (rarity < 70) {
            return "common";
        } else if (rarity < 84) {
            return "rare";
        } else if (rarity < 91) {
            return "veryRare";
        } else if (rarity < 96) {
            return "exotic";
        } else if (rarity < 99) {
            return "celestial";
        } else {
            return "epic";
        }
    }

    function multiplyUp(uint256 base, uint256 multiplier) internal pure returns (uint256) {
        uint256 scaled = base.mul(multiplier);
        return scaled / 100;
    }

    function getRangeWith(string memory rarity, range memory rangeValues) internal pure returns(range memory) {
        uint256 multiplier = 100;

        if (compareStrings(rarity, "common")) {
            multiplier = 110;
        } else if (compareStrings(rarity, "rare")) {
            multiplier = 120;
        } else if (compareStrings(rarity, "veryRare")) {
            multiplier = 130;
        } else if (compareStrings(rarity, "exotic")) {
            multiplier = 150;
        } else if (compareStrings(rarity, "celestial")) {
            multiplier = 160;
        }  else if (compareStrings(rarity, "epic")) {
            multiplier = 170;
        }
        

        return range({
            defenseMin: multiplyUp(rangeValues.defenseMin, multiplier),
            defenseMax: multiplyUp(rangeValues.defenseMax, multiplier) > 100 ? 100 : multiplyUp(rangeValues.defenseMax, multiplier),
            attackMin: multiplyUp(rangeValues.attackMin, multiplier),
            attackMax: multiplyUp(rangeValues.attackMax, multiplier) > 100 ? 100 : multiplyUp(rangeValues.attackMax, multiplier),
            soulMin:multiplyUp(rangeValues.soulMin, multiplier),
            soulMax: multiplyUp(rangeValues.soulMax, multiplier) > 100 ? 100 : multiplyUp(rangeValues.soulMax, multiplier),
            wisdomMin: multiplyUp(rangeValues.wisdomMin, multiplier),
            wisdomMax: multiplyUp(rangeValues.wisdomMax, multiplier) > 100 ? 100 : multiplyUp(rangeValues.wisdomMax, multiplier)
        });
    }

    // Normal mint
    function mint() public payable nonReentrant {
        require(!paused, "Minting is paused");
        require(price <= msg.value, "Ether value sent is not correct");
        _internalMint("");
    }

     // Normal mint
    function mintWithName(string memory _name) public payable nonReentrant {
        require(!paused, "Minting is paused");
        require(priceMintWithName <= msg.value, "Ether value sent is not correct");
        _internalMint(_name);
    }

    // Allow the owner to claim a nft
    function ownerClaim() public nonReentrant onlyOwner {
        _internalMint("");
    }

      // Called by every function after safe access checks
    function _internalMint(string memory _name) internal returns (uint256) {
        require(bytes(_name).length < 20, "Name is too long, max 20 characters");

        // minting logic
        uint256 current = _tokenIds.current();
        require(current <= maxTokens, "Max token reached");

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        _createCreature(tokenId, _name);
        _safeMint(_msgSender(), tokenId);
        return tokenId;
    }

    // Create general
    function _createCreature(uint256 _tokenId, string memory _name) internal {
        string memory family = pluck(_tokenId, "type", families);
        string memory rarity = getRarity();
        range memory rangeValues = getRangeWith(rarity, rangesByFamily[family]);
       //console.log("Defense is %s ", rangeValues.defenseMin);
        creatures[_tokenId].nickname = _name;
        creatures[_tokenId].rarity = rarity;
        creatures[_tokenId].family = family;
        creatures[_tokenId].defense = randomFromString("defense", rangeValues.defenseMax - rangeValues.defenseMin) + rangeValues.defenseMin;
        creatures[_tokenId].attack = randomFromString("attack", rangeValues.attackMax - rangeValues.attackMin) + rangeValues.attackMin;
        creatures[_tokenId].soul = randomFromString("soul", rangeValues.soulMax - rangeValues.soulMin) + rangeValues.soulMin;
        creatures[_tokenId].wisdom = randomFromString("wisdom", rangeValues.wisdomMax - rangeValues.wisdomMin) + rangeValues.wisdomMin;
       
        emit CreatureCreated(
            creatures[_tokenId].nickname,
            _tokenId,
            creatures[_tokenId]
        );
    }
  

    /**
     * @dev Base URI for computing {tokenURI}. Empty by default, can be overriden
     * in child contracts.
     */
    string private baseURI = "ipfs://";

    function _baseURI() override internal view virtual returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    } 

    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

   
}