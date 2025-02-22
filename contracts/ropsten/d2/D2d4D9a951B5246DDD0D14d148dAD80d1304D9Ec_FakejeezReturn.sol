// Contract based on https://docs.openzeppelin.com/contracts/4.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract FakejeezReturn is ERC721, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _nextMintId;
    
    // Sale settings
    uint256 public constant MAX_PURCHASE_PER_TX = 50;
    uint256 public constant MAX_PURCHASE_PER_ADDRESS = 50;
    uint256 public constant FKJZRE_PRICE = 25000000000000000; //WEI, 25000000 GWEI, 25 FINNEY 0.025 ETH
    uint256 public constant MAX_SUPPLY = 80;
    uint256 public constant LAUNCH_TIMESTAMP = 1641927600;
    uint256 public constant RESERVED_AMOUNT = 50;

    string public provenance;
    string private _baseTokenURI;
    uint256 private _creationTimestamp;
    uint256 public offsetIndex;

    // URI edition freeze status: 0=editable, 1=freeze
    uint256 public isURILocked;

    // Reserved TJZs claim status: 0=not claimed, 1=claimed
    uint256 public isReservedClaimed;

    // Minting state: 0=paused, 1=open
    uint256 public isMintingLive;

    // Metadata Reveal State: 0=hidden, 1=revealed
    uint256 public isReveal;

    address dev1 = 0x1823FdDd74B439144B5b04B87f1cCc115F121F3a;
    address dev2 = 0x1823FdDd74B439144B5b04B87f1cCc115F121F3a;
    address dev3 = 0x1823FdDd74B439144B5b04B87f1cCc115F121F3a;
    address dev4 = 0x1823FdDd74B439144B5b04B87f1cCc115F121F3a;

    ////////////////////////////////////////////////

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _nextMintId.increment();
        _creationTimestamp = block.timestamp;
    }

    // Mint reserved for the team, friends and family and giveaway (basically first #50)
    function mintReserved () external onlyOwner {
        require(isReservedClaimed == 0, "Reserved Teejeez have already been claimed");
        isReservedClaimed = 1;

        for(uint i = 0; i < RESERVED_AMOUNT; i++) {
            uint mintIndex = _nextMintId.current();
            address currentAddress = dev1;

            if (mintIndex > 8 && mintIndex <= 16) {
                currentAddress = dev2;
            }
            if (mintIndex > 16 && mintIndex <= 20) {
                currentAddress = dev3;
            }
            if (mintIndex > 20 && mintIndex <= 24) {
                currentAddress = dev4;
            }
            if (mintIndex == 25) {
                currentAddress = address(0x1823FdDd74B439144B5b04B87f1cCc115F121F3a);
            }
            if (_nextMintId.current() <= MAX_SUPPLY) {
                _nextMintId.increment();
                _safeMint(currentAddress, mintIndex);
            }
        }
    }

    /*
    * --- MINTING
    */

    function mintTJZ(uint256 tokenAmount) public payable {
        require(block.timestamp >= LAUNCH_TIMESTAMP, "Mint isn't open yet : Opening 01/11/22, 20:00 GMT+1");
        require(isMintingLive == 1, "Minting must be active to mint a Teejeez");
        require(tokenAmount <= MAX_PURCHASE_PER_TX, "You can only mint 10 Teejeez at a time");
        require(balanceOf(msg.sender).add(tokenAmount) <= MAX_PURCHASE_PER_ADDRESS, "You can only mint a maximum of 20 Teejeez per wallet");
        require(_nextMintId.current().add(tokenAmount) <= MAX_SUPPLY.add(1), "The mint would exceed Teejeez max supply");
        require(FKJZRE_PRICE.mul(tokenAmount) <= msg.value, "Ether value sent is uncorrect");
        
        for(uint i = 0; i < tokenAmount; i++) {
            uint mintIndex = _nextMintId.current();
            if (_nextMintId.current() <= MAX_SUPPLY) {
                _nextMintId.increment();
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    /*
    * --- TOKEN URI
    */
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        require(isURILocked == 0, "the baseURI can no longer be changed");
        _baseTokenURI = baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory baseURI = _baseURI();
        string memory sequenceId;

        if (isReveal == 1) {
            if(( (tokenId + offsetIndex) % MAX_SUPPLY ) == 0) {
                sequenceId = MAX_SUPPLY.toString();
            } else {
                sequenceId = ( (tokenId + offsetIndex) % MAX_SUPPLY ).toString();
            }
        } else {
            sequenceId = "0";
        }

        return string(abi.encodePacked(baseURI, sequenceId, ".json"));
    }

    function lockURI() external onlyOwner() {
        isURILocked = 1;
    }

    function setStartingIndex() external {
        require(offsetIndex == 0, "Starting index is already set");

        offsetIndex = uint(_creationTimestamp + block.timestamp) % MAX_SUPPLY;

        // Prevent default sequence
        if (offsetIndex == 0) {
            offsetIndex = 1;
        }
    }

    /*
    * --- UTILITIES
    */
    function toggleMintingState() external onlyOwner {
        isMintingLive == 0 ? isMintingLive = 1 : isMintingLive = 0;
    }

    function toggleRevealState() external onlyOwner {
        isReveal == 0 ? isReveal = 1 : isReveal = 0;
    }

    function setProvenance(string memory provenanceHash) external onlyOwner {
        provenance = provenanceHash;
    }

    function totalSupply() public view returns(uint256) {
        return _nextMintId.current() - 1;
    }

    // Funds are safe
    function withdrawBalance() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}