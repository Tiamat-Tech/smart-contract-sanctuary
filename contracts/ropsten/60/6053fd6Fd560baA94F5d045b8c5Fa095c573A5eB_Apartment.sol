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

contract Apartment is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => uint256) private tierLevel;

    uint private totalApartmentSupply = 11000;

    uint private supplyRarityLevelOne = 50; //totalApartmentSupply * 0.45 / 100; // 50;
    uint private supplyRarityLevelTwo = 98; //totalApartmentSupply * 0.89 / 100; // 98;
    uint private supplyRarityLevelThree = 190; //totalApartmentSupply * 1.73 / 100; // 190;
    uint private supplyRarityLevelFour = 372; //totalApartmentSupply * 3.38 / 100; //372;
    uint private supplyRarityLevelFive = 725; //totalApartmentSupply * 6.59 / 100; //725;
    uint private supplyRarityLevelSix = 1415; // totalApartmentSupply * 12.86 / 100; //1415;
    uint private supplyRarityLevelSeven = 2761; // totalApartmentSupply * 25.10 / 100; // 2761;
    uint private supplyRarityLevelEight = 5389; //totalApartmentSupply * 48.99 / 100; // 5389;

    uint private counterRarityLevelOne = 0;
    uint private counterRarityLevelTwo = 0;
    uint private counterRarityLevelThree = 0;
    uint private counterRarityLevelFour = 0;
    uint private counterRarityLevelFive = 0;
    uint private counterRarityLevelSix = 0;
    uint private counterRarityLevelSeven = 0;
    uint private counterRarityLevelEight = 0;

    uint private rewardRateLevelOne = 17211;
    uint private rewardRateLevelTwo = 11474;
    uint private rewardRateLevelThree = 7650;
    uint private rewardRateLevelFour = 5100;
    uint private rewardRateLevelFive = 3400;
    uint private rewardRateLevelSix = 2267;
    uint private rewardRateLevelSeven = 1511;
    uint private rewardRateLevelEight = 1007;

    constructor() ERC721("Apartment", "APT") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }


    function mintApartment() public {
        _mintApartment();
    }

    function _mintApartment() private {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        uint randomTierLevel = generateRandomTierLevel();
        tierLevel[tokenId] =  randomTierLevel;
    }

    
    function generateRandomTierLevel() private returns (uint) {
        uint randomNumber = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % 8;
        randomNumber = randomNumber + 1;

        if (randomNumber == 1) {
            console.log("Rarity Tier Generated: 1");
            if (counterRarityLevelOne >= supplyRarityLevelOne) { // 1 rarity is full
                console.log("Rarity 1 is full.");
                if (counterRarityLevelTwo >= supplyRarityLevelTwo) {
                    console.log("Rarity 2 is full.");
                    if(counterRarityLevelThree >= supplyRarityLevelThree) {
                        console.log("Rarity 3 is full.");
                        if(counterRarityLevelFour >= supplyRarityLevelFour) {
                            console.log("Rarity 4 is full.");
                            if(counterRarityLevelFive >= supplyRarityLevelFive) {
                                console.log("Rarity 5 is full.");
                                if (counterRarityLevelSix >= supplyRarityLevelSix) {
                                    console.log("Rarity 6 is full.");
                                    if (counterRarityLevelSeven >= supplyRarityLevelSeven) {
                                        console.log("Rarity 7 is full.");
                                        if (counterRarityLevelEight >= supplyRarityLevelEight) {
                                            console.log("Rarity 8 is full.");
                                            randomNumber = 0;
                                        } else {
                                            counterRarityLevelEight++;
                                            randomNumber = 8;
                                        }
                                    } else {
                                        counterRarityLevelSeven++;
                                        randomNumber = 7;
                                    }
                                } else {
                                    counterRarityLevelSix++;
                                    randomNumber = 6;
                                }
                            } else {
                                counterRarityLevelFive++;
                                randomNumber = 5;
                            }
                        } else {
                            counterRarityLevelFour++;
                            randomNumber = 4;
                        }
                    } else {
                        counterRarityLevelThree++;
                        randomNumber = 3;
                    }
                } else {
                    counterRarityLevelTwo++;
                    randomNumber = 2;
                }
            } else {
                counterRarityLevelOne++;
                randomNumber = 1;
            }

        } else if (randomNumber == 2) {
            console.log("Rarity Tier Generated: 2");
            if (counterRarityLevelTwo >= supplyRarityLevelTwo) { // 2 rarity is full
                console.log("Rarity 2 is full.");
                    if(counterRarityLevelThree >= supplyRarityLevelThree) {
                        console.log("Rarity 3 is full.");
                        if(counterRarityLevelFour >= supplyRarityLevelFour) {
                            console.log("Rarity 4 is full.");
                            if(counterRarityLevelFive >= supplyRarityLevelFive) {
                                console.log("Rarity 5 is full.");
                                if (counterRarityLevelSix >= supplyRarityLevelSix) {
                                    console.log("Rarity 6 is full.");
                                    if (counterRarityLevelSeven >= supplyRarityLevelSeven) {
                                        console.log("Rarity 7 is full.");
                                        if (counterRarityLevelEight >= supplyRarityLevelEight) {
                                            console.log("Rarity 8 is full.");
                                             if (counterRarityLevelOne >= supplyRarityLevelOne) { // 1 rarity is full
                                                console.log("Rarity 1 is full.");
                                                randomNumber = 0;
                                             }  else {
                                                counterRarityLevelOne++;
                                                randomNumber = 1;
                                            }
                                        } else {
                                            counterRarityLevelEight++;
                                            randomNumber = 8;
                                        }
                                    } else {
                                        counterRarityLevelSeven++;
                                        randomNumber = 7;
                                    }
                                } else {
                                    counterRarityLevelSix++;
                                    randomNumber = 6;
                                }
                            } else {
                                counterRarityLevelFive++;
                                randomNumber = 5;
                            }
                        } else {
                            counterRarityLevelFour++;
                            randomNumber = 4;
                        }
                    } else {
                        counterRarityLevelThree++;
                        randomNumber = 3;
                    }
            } else {
                counterRarityLevelTwo++;
                randomNumber = 2;
            }

        } else if (randomNumber == 3) {
            console.log("Rarity Tier Generated: 3");
            if (counterRarityLevelThree >= supplyRarityLevelThree) { // 3 rarity is full
                if(counterRarityLevelFour >= supplyRarityLevelFour) {
                    console.log("Rarity 4 is full.");
                    if(counterRarityLevelFive >= supplyRarityLevelFive) {
                        console.log("Rarity 5 is full.");
                        if (counterRarityLevelSix >= supplyRarityLevelSix) {
                            console.log("Rarity 6 is full.");
                            if (counterRarityLevelSeven >= supplyRarityLevelSeven) {
                                console.log("Rarity 7 is full.");
                                if (counterRarityLevelEight >= supplyRarityLevelEight) {
                                    console.log("Rarity 8 is full.");
                                    if(counterRarityLevelTwo >= supplyRarityLevelTwo) {
                                        console.log("Rarity 2 is full.");
                                        if(counterRarityLevelOne >= supplyRarityLevelOne) {
                                            console.log("Rarity 1 is full.");
                                            randomNumber = 0;
                                        } else {
                                            counterRarityLevelOne++;
                                            randomNumber = 1;
                                        }
                                    } else {
                                        counterRarityLevelTwo++;
                                        randomNumber = 2;
                                    }

                                    randomNumber = 0;
                                } else {
                                    counterRarityLevelEight++;
                                    randomNumber = 8;
                                }
                            } else {
                                counterRarityLevelSeven++;
                                randomNumber = 7;
                            }
                        } else {
                            counterRarityLevelSix++;
                            randomNumber = 6;
                        }
                    } else {
                        counterRarityLevelFive++;
                        randomNumber = 5;
                    }
                } else {
                    counterRarityLevelFour++;
                    randomNumber = 4;
                }
            } else {
                counterRarityLevelThree++;
                randomNumber = 3;
            }

        } else if (randomNumber == 4) {
            console.log("Rarity Tier Generated: 4");
            if (counterRarityLevelFour >= supplyRarityLevelFour) { // 4 rarity is full
                if(counterRarityLevelFive >= supplyRarityLevelFive) {
                    console.log("Rarity 5 is full.");
                    if (counterRarityLevelSix >= supplyRarityLevelSix) {
                        console.log("Rarity 6 is full.");
                            if (counterRarityLevelSeven >= supplyRarityLevelSeven) {
                                console.log("Rarity 7 is full.");
                                if (counterRarityLevelEight >= supplyRarityLevelEight) {
                                    console.log("Rarity 8 is full.");
                                    if(counterRarityLevelThree >= supplyRarityLevelThree) {
                                        console.log("Rarity 3 is full.");
                                            if(counterRarityLevelTwo >= supplyRarityLevelTwo) {
                                                console.log("Rarity 2 is full.");
                                                if(counterRarityLevelOne >= supplyRarityLevelOne) {
                                                    console.log("Rarity 1 is full.");
                                                    randomNumber = 0;
                                                } else {
                                                    counterRarityLevelOne++;
                                                    randomNumber = 1;
                                                }
                                            } else {
                                                counterRarityLevelTwo++;
                                                randomNumber = 2;
                                            }

                                    } else {
                                        counterRarityLevelThree++;
                                        randomNumber = 3;
                                    }
                                } else {
                                    counterRarityLevelEight++;
                                    randomNumber = 8;
                                }
                            } else {
                                counterRarityLevelSeven++;
                                randomNumber = 7;
                            }
                        } else {
                            counterRarityLevelSix++;
                            randomNumber = 6;
                        }
                    } else {
                        counterRarityLevelFive++;
                        randomNumber = 5;
                    }
            } else {
                counterRarityLevelFour++;
                randomNumber = 4;
            }

        } else if (randomNumber == 5) {
            console.log("Rarity Tier Generated: 5");
            if (counterRarityLevelFive >= supplyRarityLevelFive) { // 5 rarity is full
                if (counterRarityLevelSix >= supplyRarityLevelSix) {
                        console.log("Rarity 6 is full.");
                            if (counterRarityLevelSeven >= supplyRarityLevelSeven) {
                                console.log("Rarity 7 is full.");
                                if (counterRarityLevelEight >= supplyRarityLevelEight) {
                                    console.log("Rarity 8 is full.");
                                    if(counterRarityLevelFour >= supplyRarityLevelFour) {
                                          if(counterRarityLevelThree >= supplyRarityLevelThree) {
                                                console.log("Rarity 3 is full.");
                                                if(counterRarityLevelTwo >= supplyRarityLevelTwo) {
                                                    console.log("Rarity 2 is full.");
                                                    if(counterRarityLevelOne >= supplyRarityLevelOne) {
                                                        console.log("Rarity 1 is full.");
                                                        randomNumber = 0;
                                                    } else {
                                                        counterRarityLevelOne++;
                                                        randomNumber = 1;
                                                    }
                                                } else {
                                                    counterRarityLevelTwo++;
                                                    randomNumber = 2;
                                                }
                                    } else {
                                        counterRarityLevelThree++;
                                        randomNumber = 3;
                                    }

                                    } else {
                                        counterRarityLevelFour++;
                                        randomNumber = 4;
                                    }
                                  
                                } else {
                                    counterRarityLevelEight++;
                                    randomNumber = 8;
                                }
                            } else {
                                counterRarityLevelSeven++;
                                randomNumber = 7;
                            }
                        } else {
                            counterRarityLevelSix++;
                            randomNumber = 6;
                        }


            } else {
                counterRarityLevelFive++;
                randomNumber = 5;
            }

        } else if (randomNumber == 6) {
            console.log("Rarity Tier Generated: 6");
            if (counterRarityLevelSix >= supplyRarityLevelSix) { // 6 rarity is full
                if (counterRarityLevelSeven >= supplyRarityLevelSeven) {
                    console.log("Rarity 7 is full.");
                    if (counterRarityLevelEight >= supplyRarityLevelEight) {
                        console.log("Rarity 8 is full.");
                        if (counterRarityLevelFive >= supplyRarityLevelFive) {
                            console.log("Rarity 5 is full.");
                            if (counterRarityLevelFour >= supplyRarityLevelFour) {
                                console.log("Rarity 4 is full.");
                                if (counterRarityLevelThree >= supplyRarityLevelThree) {
                                    console.log("Rarity 3 is full.");
                                    if (counterRarityLevelTwo >= supplyRarityLevelTwo) {
                                         console.log("Rarity 2 is full.");
                                         if (counterRarityLevelOne >= supplyRarityLevelOne) {
                                              console.log("Rarity 1 is full.");
                                              randomNumber = 0;
                                         } else {
                                             counterRarityLevelOne++;
                                             randomNumber = 1;
                                         }
                                    } else {
                                        counterRarityLevelTwo++;
                                        randomNumber = 2;
                                    }

                                } else {
                                    counterRarityLevelThree ++;
                                    randomNumber = 3;
                                }

                            } else {
                                counterRarityLevelFour++;
                                randomNumber = 4;
                            }

                        } else {
                            counterRarityLevelFive++;
                            randomNumber = 5;
                        }
                        
                    } else {
                        counterRarityLevelEight++;
                        randomNumber = 8;
                    }
                } else {
                    counterRarityLevelSeven++;
                    randomNumber = 7;
                }

            } else {
                counterRarityLevelSix++;
                randomNumber = 6;
            }

        } else if (randomNumber == 7) {
            console.log("Rarity Tier Generated: 7");
            if (counterRarityLevelSeven >= supplyRarityLevelSeven) { // 7 rarity is full
                console.log("Rarity 7 is full.");
                if (counterRarityLevelEight >= supplyRarityLevelEight) {
                    console.log("Rarity 8 is full.");
                    if (counterRarityLevelSix >= supplyRarityLevelSix) {
                        console.log("Rarity 6 is full");
                        if (counterRarityLevelFive >= supplyRarityLevelFive) {
                            console.log("Rarity 5 is full.");
                            if (counterRarityLevelFour >= supplyRarityLevelFour) {
                                console.log("Rarity 4 is full.");
                                if (counterRarityLevelThree >= supplyRarityLevelThree) {
                                    console.log("Rarity 3 is full.");
                                    if (counterRarityLevelTwo >= supplyRarityLevelTwo) {
                                         console.log("Rarity 2 is full.");
                                         if (counterRarityLevelOne >= supplyRarityLevelOne) {
                                              console.log("Rarity 1 is full.");
                                              randomNumber = 0;
                                         } else {
                                             counterRarityLevelOne++;
                                             randomNumber = 1;
                                         }
                                    } else {
                                        counterRarityLevelTwo++;
                                        randomNumber = 2;
                                    }

                                } else {
                                    counterRarityLevelThree ++;
                                    randomNumber = 3;
                                }

                            } else {
                                counterRarityLevelFour++;
                                randomNumber = 4;
                            }

                        } else {
                            counterRarityLevelFive++;
                            randomNumber = 5;
                        }

                    } else {
                        counterRarityLevelSix ++;
                        randomNumber = 6;
                    }

                } else {
                    counterRarityLevelEight++;
                    randomNumber = 8;
                }


            } else {
                counterRarityLevelSeven++;
                randomNumber = 7;
            }

        } else if (randomNumber == 8) {
            console.log("Rarity Tier Generated: 8");
            if (counterRarityLevelEight >= supplyRarityLevelEight) { // 8 rarity is full
                console.log("Rarity 8 is full");
                    if (counterRarityLevelSeven >= supplyRarityLevelSeven) {
                        console.log("Rarity 7 is full");
                            if (counterRarityLevelSix >= supplyRarityLevelSix) {
                            console.log("Rarity 6 is full");
                            if (counterRarityLevelFive >= supplyRarityLevelFive) {
                                console.log("Rarity 5 is full.");
                                if (counterRarityLevelFour >= supplyRarityLevelFour) {
                                    console.log("Rarity 4 is full.");
                                    if (counterRarityLevelThree >= supplyRarityLevelThree) {
                                        console.log("Rarity 3 is full.");
                                        if (counterRarityLevelTwo >= supplyRarityLevelTwo) {
                                            console.log("Rarity 2 is full.");
                                            if (counterRarityLevelOne >= supplyRarityLevelOne) {
                                                console.log("Rarity 1 is full.");
                                                randomNumber = 0;
                                            } else {
                                                counterRarityLevelOne++;
                                                randomNumber = 1;
                                            }
                                        } else {
                                            counterRarityLevelTwo++;
                                            randomNumber = 2;
                                        }

                                    } else {
                                        counterRarityLevelThree ++;
                                        randomNumber = 3;
                                    }

                                } else {
                                    counterRarityLevelFour++;
                                    randomNumber = 4;
                                }

                            } else {
                                counterRarityLevelFive++;
                                randomNumber = 5;
                            }

                        } else {
                            counterRarityLevelSix ++;
                            randomNumber = 6;
                        }

                    } else {
                        counterRarityLevelSeven ++;
                        randomNumber = 7;
                    }

            } else {
                counterRarityLevelEight++;
                randomNumber = 8;
            }

        } else {

        } 

        console.log("Random Hash: ", randomNumber);
        return randomNumber;
    } 

    function getApartmentTierLevel(uint apartmentID) public view returns(uint) {
        return tierLevel[apartmentID];
    }

    function getRewardRate(uint _Level) public view returns (uint) {
        if(_Level == 1) {
            return rewardRateLevelOne;
        } else if (_Level == 2){
            return rewardRateLevelTwo;
        } else if (_Level == 3){
            return rewardRateLevelThree;
        } else if (_Level == 4){
            return rewardRateLevelFour;
        } else if (_Level == 5){
            return rewardRateLevelFive;
        } else if (_Level == 6){
            return rewardRateLevelSix;
        } else if (_Level == 7){
            return rewardRateLevelSeven;
        } else if (_Level == 8){
            return rewardRateLevelEight;
        }
        return 0;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
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