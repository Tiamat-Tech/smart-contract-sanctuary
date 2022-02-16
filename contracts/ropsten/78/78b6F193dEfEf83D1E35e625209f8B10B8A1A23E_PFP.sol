// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
/// @custom:security-contact [email protected]

contract PFP is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint => uint ) private alphaScore;

    uint private totalPFPSupply = 10000;

    uint private raritySixSupply = totalPFPSupply * 45 / 100;
    uint private raritySevenSupply = totalPFPSupply * 26 / 100;
    uint private rarityEightSupply = totalPFPSupply * 15 / 100;
    uint private rarityNineSupply = totalPFPSupply * 9 / 100;
    uint private rarityTenSupply = totalPFPSupply * 5 / 100;

    uint private counterRaritySix = 0;
    uint private counterRaritySeven = 0;
    uint private counterRarityEight = 0;
    uint private counterRarityNine = 0;
    uint private counterRarityTen = 0;

    constructor() ERC721("PFP", "PFP") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mintPFP() public {
        _mintRandomPFP();
       
    }

    function _mintRandomPFP() private {
    console.log("TotalSupply: ", totalSupply(), " - Total PFP Supply: ", totalPFPSupply);
        require(totalSupply() < totalPFPSupply, "Total Supply reached limit.");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        uint256 randomScore = randomPFPAlphaScore();
        alphaScore[tokenId] =  randomScore; //call a function from ChainLink Verifiable Random Function (VRF)
    }

    function setPFPURI(uint256 pfpID, string memory _tokenURI) public {
        require(ownerOf(pfpID) == msg.sender , "You do not own this PFP.");
        _setTokenURI(pfpID, _tokenURI);

    }

    function getPFPAlphaScore(uint256 pfpID) public view returns(uint256) {
        return alphaScore[pfpID];
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function randomPFPAlphaScore() private returns (uint256) {
        uint256 randomHash = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % 5;
        randomHash = randomHash + 6;
            if (randomHash == 6) {
                console.log("Rarity Generated: 6");
                if (counterRaritySix >= raritySixSupply) { // 6 rarity is full
                    console.log("Rarity 6 is full.");
                    if (counterRaritySeven >= raritySevenSupply) { // 7 rarity is full
                         console.log("Rarity 7 is full.");
                        if (counterRarityEight >= rarityEightSupply) { // 8 rarity is full
                            console.log("Rarity 8 is full.");
                            if (counterRarityNine >= rarityNineSupply) {
                                    console.log("Rarity 9 is full.");
                                    if (counterRarityTen >= rarityTenSupply) {
                                        console.log("Rarity 10 is full.");
                                        randomHash = 0;
                                    } else {
                                        counterRarityTen++;
                                        randomHash = 10;
                                    }
                            } else {
                                counterRarityNine++;
                                randomHash = 9;
                            }
 
                        } else {
                            counterRarityEight++;
                            randomHash = 8;
                        }
                } else {
                    counterRaritySeven++;
                    randomHash = 7;                    
                } 
                } else {
                    
                    counterRaritySix++;
                    console.log("Rarity 6 Counter: ", counterRaritySix, " - RaritySupply: ", raritySixSupply);
                    
                }

            } else if (randomHash == 7) {
                if (counterRaritySeven >= raritySevenSupply) { // 7 rarity is full
                    console.log("Rarity 7 is full.");
                    if (counterRaritySix >= raritySixSupply) { // 6 rarity is full
                        console.log("Rarity 6 is full.");
                        if (counterRarityEight >= rarityEightSupply) { // 8 rarity is full
                            console.log("Rarity 8 is full.");
                            if (counterRarityNine >= rarityNineSupply) {
                                    console.log("Rarity 9 is full.");
                                    if (counterRarityTen >= rarityTenSupply) {
                                        randomHash = 0;
                                    } else {
                                        counterRarityTen++;
                                        randomHash = 10;
                                    }
                            } else {
                                counterRarityNine++;
                                randomHash = 9;
                            }
 
                        } else {
                            counterRarityEight++;
                            randomHash = 8;
                        }


                    } else {
                        counterRaritySix++;
                        randomHash = 6;
                    }
                } else {
                    console.log("Rarity Generated: 7");
                    counterRaritySeven++;
                    console.log("Rarity 7 Counter: ", counterRaritySeven, " - RaritySupply: ", raritySevenSupply);
                    
                } 
            } else if (randomHash == 8) {
                if (counterRarityEight >= rarityEightSupply) { // 8 rarity is full
                    console.log("Rarity 8 is full.");
                    if(counterRaritySeven >= raritySevenSupply) {
                        console.log("Rarity 7 is full.");
                            if (counterRaritySix >= raritySixSupply) {
                                    console.log("Rarity 6 is full.");
                                    if (counterRarityNine >= rarityNineSupply) {
                                        console.log("Rarity 9 is full.");
                                        if (counterRarityTen >= rarityTenSupply) {
                                            console.log("Rarity 10 is full.");
                                            randomHash = 0; // Total Supply Finished.
                                        } else {
                                            counterRarityTen++;
                                            randomHash = 10;
                                    }

                                    } else {
                                        counterRarityNine++;
                                        randomHash = 9;
                                    }

                                } else {
                                    counterRaritySix++;
                                    randomHash = 6;
                                }

                    } else {
                        counterRaritySeven++;
                        randomHash = 7;
                    }
                    
                } else {
                    console.log("Rarity Generated: 8");
                    counterRarityEight++;
                    console.log("Rarity 8 Counter: ", counterRarityEight, " - RaritySupply: ", rarityEightSupply);
                   
                }
            } else if (randomHash == 9) {
                if (counterRarityNine >= rarityNineSupply) { // 9 rarity is full
                    console.log("Rarity 9 is full.");
                     if(counterRarityEight >= rarityEightSupply) {
                            console.log("Rarity 8 is full.");
                            if(counterRaritySeven >= raritySevenSupply) {
                                console.log("Rarity 7 is full.");
                                if (counterRaritySix >= raritySixSupply) {
                                    console.log("Rarity 6 is full.");
                                    if (counterRarityTen >= rarityTenSupply) {
                                        console.log("Rarity 10 is full.");
                                        randomHash = 0; // Total Supply Finished.
                                    } else {
                                        counterRarityTen++;
                                        randomHash = 10;
                                    }

                                } else {
                                    counterRaritySix++;
                                    randomHash = 6;
                                }
                            } else {
                                counterRaritySeven++;
                                randomHash = 7;
                            }

                        } else {
                            counterRarityEight++;
                            randomHash = 8;
                        }
                } else {
                    console.log("Rarity Generated: 9");
                    counterRarityNine++;
                    console.log("Rarity 9 Counter: ", counterRarityNine, " - RaritySupply: ", rarityNineSupply);
                    
                }
            } else if (randomHash == 10) {
                if (counterRarityTen >= rarityTenSupply) { // 10 rarity is full
                    console.log("Rarity 10 is full.");
                    if(counterRarityNine >= rarityNineSupply) {
                        console.log("Rarity 9 is full.");
                        if(counterRarityEight >= rarityEightSupply) {
                            console.log("Rarity 8 is full.");
                            if(counterRaritySeven >= raritySevenSupply) {
                                console.log("Rarity 7 is full.");
                                if (counterRaritySix >= raritySixSupply) {
                                    console.log("Rarity 6 is full.");
                                    // Total Supply Finished.
                                    randomHash = 0;
                                } else {
                                    counterRaritySix++;
                                    randomHash = 6;
                                }
                            } else {
                                counterRaritySeven++;
                                randomHash = 7;
                            }


                        } else {
                            counterRarityEight++;
                            randomHash = 8;
                        }
                        
                    } else {
                        counterRarityNine++;
                        randomHash = 9;
                    }

                } else {
                    console.log("Rarity Generated: 10");
                    counterRarityTen++;
                    console.log("Rarity 10 Counter: ", counterRarityTen, " - RaritySupply: ", rarityTenSupply);
                }
            }
        
        console.log("Random Hash: ", randomHash);
        return randomHash;
    } 

    function getAlphaRaritySupply(uint _alphaScore) public view returns (uint) {
        require(_alphaScore > 5 , "Alpha Score must be greater than 5");
        require (_alphaScore <= 10, "Alpha Score must be less than 10");
        if (_alphaScore == 6) {
            return raritySixSupply;
        } else if (_alphaScore == 7) {
            return raritySevenSupply;
        } else if (_alphaScore == 8) {
            return rarityEightSupply;
        } else if (_alphaScore == 9) {
            return rarityNineSupply;
        } else if (_alphaScore == 10) {
            return rarityTenSupply;
        } else
        return 0;
    }
    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}