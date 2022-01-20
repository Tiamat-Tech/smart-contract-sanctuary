// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
Twitter: https://twitter.com/AlphaSocietyNFT
Website: https://alphasociety.club
Discord: https://discord.gg/CHANGEME
*/


contract AlphaSociety is ERC721Enumerable, Ownable {
    uint256 public constant presaleCost = 0.09 ether;
    uint256 public constant availableNFTs = 6666;
    uint256 public constant publicSaleMaxTokens = 3;
    uint256 public constant presaleMaxTokens = 5;

    bytes32 private merkleRoot;
    string private baseURI;

    /// @dev Inactive = 0; Presale = 1; Public = 2;
    uint256 private saleFlag = 0;
    bool private metadataLocked = false;

    mapping(address => uint256) private amountMintedPerUser;
    mapping(address => bool) private hasClaimedWhitelist;

    constructor(
        string memory _base,
        bytes32 _merkleRoot
    ) ERC721("Alpha Society", "ALPHA") {
        baseURI = _base;
        merkleRoot = _merkleRoot;
    }

    function lockMetadata() external onlyOwner {
        metadataLocked = true;
    }

    function setFlag(uint256 _new) external onlyOwner onlyUnlocked {
        saleFlag = _new;
    }

    function setMerkleRoot(bytes32 _newRoot) external onlyOwner onlyUnlocked {
        merkleRoot = _newRoot;
    }

    function setBaseURI(string memory _base) external onlyOwner onlyUnlocked {
        baseURI = _base;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    modifier onlyUnlocked() {
        require(!metadataLocked, "METADATA_LOCKED");
        _;
    }

    modifier onlyWhitelist(bytes32[] calldata _merkleProof) {
        require(hasClaimedWhitelist[msg.sender] == false, "HAS_ALREADY_MINTED");
        require(MerkleProof.verify(
            _merkleProof, merkleRoot, keccak256(abi.encodePacked(msg.sender))), "INVALID_MERKLE_PROOF");
        _;
    }

    function mintWhitelist(bytes32[] calldata _merkleProof) external payable onlyWhitelist(_merkleProof) {        
        uint256 supply = this.totalSupply();
        require(supply + 1 <= availableNFTs, "EXCEEDS_TOTAL_SUPPLY");
        require(msg.value == presaleCost, "INVALID_VALUE");
        require(saleFlag == 1, "MINTING_PAUSED");

        _mint(msg.sender, supply);
    
        hasClaimedWhitelist[msg.sender] = true;
    }

    function mint(uint256 _amount) external payable {
        uint256 supply = this.totalSupply();
        require(supply + _amount <= availableNFTs, "EXCEEDS_TOTAL_SUPPLY");
        require(msg.value == presaleCost * _amount, "INVALID_VALUE");
        require(saleFlag == 2, "MINTING_PAUSED");
        require(_amount <= 5, "_AMOUNT_TOO_HIGH");
        require(amountMintedPerUser[msg.sender] + _amount <= publicSaleMaxTokens, "EXCEEDS_MINT_LIMIT");
        require(tx.origin == msg.sender, "SENDER_IS_NOT_AN_EOA");

        for (uint256 i = 0; i < _amount; i++) {
            _mint(msg.sender, supply + i);
        }

        amountMintedPerUser[msg.sender] += _amount;
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}

// contract Meridian is ERC721, Ownable {
//     string public baseMetadataURI;

//     uint16 public preSaleNFTs = 2500;
//     uint8 public preSaleMaxTokens = 5;
//     uint256 public preSaleCost = 0.06 ether;

//     uint16 public availableNFTs = 10000;
//     uint16 public mintedNFTs = 0;
//     uint8 public maxTokensPerWallet = 8;
//     uint256 public cost = 0.07 ether;

//     uint16 public tokenId;
//     bool public preSaleActive;
//     mapping(address => uint8) public freeMintAddr;
//     mapping(address => uint16) public walletToToken;

//     // trait masks
//     bytes8 public groupMask = bytes8(uint64(0x38000000000));
//     bytes8 public founderMask = bytes8(uint64(0x4000000000));
//     bytes8 public backgroundMask = bytes8(uint64(0x3C00000000));
//     bytes8 public headMask = bytes8(uint64(0x3F0000000));
//     bytes8 public faceMask = bytes8(uint64(0x8000000));
//     bytes8 public chestMask = bytes8(uint64(0x7C00000));
//     bytes8 public poseMask = bytes8(uint64(0x300000));
//     bytes8 public legsMask = bytes8(uint64(0xF0000));
//     bytes8 public bootsMask = bytes8(uint64(0xF000));
//     bytes8 public accessoriesMask = bytes8(uint64(0xF00));
//     bytes8 public lHandMask = bytes8(uint64(0xF8));
//     bytes8 public rHandMask = bytes8(uint64(0x7));

//     // founder
//     uint16 public founders = 0;

//     // trait maps
//     mapping(uint64 => uint64) public groupMap;
//     mapping(uint64 => uint64) public headMap;
//     mapping(uint64 => uint64) public chestMap;
//     mapping(uint64 => uint64) public legsMap;
//     mapping(uint64 => uint64) public bootsMap;
//     mapping(uint64 => uint64) public handMap;
//     mapping(uint64 => uint64) public backgroundMap;
//     mapping(uint64 => uint64) public accessoriesMap;

//     // minted traits and combinations
//     mapping(uint256 => bytes8) public tokenTraits;
//     mapping(uint64 => uint8) public existingCombinations;

//     constructor(
//         string memory _collectionName, 
//         string memory _collectionSymbol, 
//         string memory _initMetadataURI,
//         address[] memory freeMinterAddresses
//         ) ERC721(_collectionName, _collectionSymbol) {
//             baseMetadataURI = _initMetadataURI;
//             for (uint i=0; i<freeMinterAddresses.length; i++) {
//                 freeMintAddr[freeMinterAddresses[i]] = 1;
//             }
//             preSaleActive = true;
//         }

//     function _baseURI() internal view virtual override returns (string memory) {
//         return baseMetadataURI;
//     }

//     function availableTokens() public view returns (uint256) {
//         return availableNFTs - mintedNFTs;
//     }

//     function tokenForWallet(address wallet) public view returns (uint256) {
//         return walletToToken[wallet];
//     }

//     function founder(uint256 tokenIdForCombination) public view returns (uint) {
//         uint64 traits = uint64(tokenTraits[tokenIdForCombination]);
//         return founderTraitIndex(traits);
//     }

//     function setFreeMinter(address minter) public onlyOwner {
//         freeMintAddr[minter] = 1;
//     }

//     function setMetadataBaseURI(string memory _newMetadataURI) public onlyOwner {
//         baseMetadataURI = _newMetadataURI;
//     }

//     function setPreSaleActive(bool active) public onlyOwner {
//         preSaleActive = active;
//     }

//     function setMaximumTokensPerWallet(uint8 value) public onlyOwner {
//         maxTokensPerWallet = value;
//     }

//     function mint(uint64 traits) external payable {
//         require(existingCombinations[traits] == 0, "Combination of traits already minted.");

//         uint8 mintAmount = 1;

//         if (preSaleActive) {
//             require(mintedNFTs + mintAmount <= preSaleNFTs, "Maximum available NFTs for presale exceeded.");
//             require(balanceOf(msg.sender) < preSaleMaxTokens, "Maximum tokens to mint reached for presale.");

//             require(msg.value >= preSaleCost * mintAmount, "Not enough funds to mind token.");
//         } else {
//             require(mintedNFTs + mintAmount <= availableNFTs, "Maximum available NFTs exceeded.");
//             require(balanceOf(msg.sender) < maxTokensPerWallet, "Maximum tokens to mint reached.");

//             require(msg.value >= cost * mintAmount, "Not enough funds to mind token.");
//         }

//         internalMint(traits);
//         _safeMint(msg.sender, tokenId);
//         mintedNFTs++;
//         tokenId++;
//     }

//     function freeMint(uint64 traits) external {
//         if (freeMintAddr[msg.sender] == 0) {
//             revert();
//         }

//         require(existingCombinations[traits] == 0, "Combination of traits already minted.");

//         uint8 mintAmount = 1;
//         require(mintedNFTs + mintAmount <= availableNFTs, "Maximum available NFTs exceeded.");
//         require(balanceOf(msg.sender) < maxTokensPerWallet, "Maximum tokens to mint reached.");

//         internalMint(traits);
//         _safeMint(msg.sender, tokenId);
//         mintedNFTs++;
//         tokenId++;
//     }

//     function contractBalance() external view onlyOwner returns (uint256) {
//         return address(this).balance;
//     }

//     function withdraw() public payable onlyOwner () {
//         payable(owner()).transfer(address(this).balance);
//     }

//     function setFounderTrait(uint64 traits) internal view returns (uint64) {
//         return uint64(bytes8(traits) | founderMask);
//     }

//     function internalMint(uint64 traits) internal {
//         if ((mintedNFTs + 1) % 10 == 0) {
//             founders++;
//             traits = setFounderTrait(traits);
//         }

//         // decode 
//         uint64 groupTrait = groupTraitIndex(traits);
//         uint64 headTrait = headTraitIndex(traits);
//         uint64 chestTrait = chestTraitIndex(traits);
//         uint64 legsTrait = legsTraitIndex(traits);
//         uint64 bootsTrait = bootsTraitIndex(traits);
//         uint64 lhandTrait = lhandTraitIndex(traits);
//         uint64 rhandTrait = rhandTraitIndex(traits);
//         uint64 backgroundTrait = backgroundTraitIndex(traits);
//         uint64 poseTrait = poseTraitIndex(traits);
//         uint64 accessoriesTrait = accessoriesTraitIndex(traits);
//         uint64 faceTrait = faceTraitIndex(traits);

//         // right hand validation
//         if (groupTrait == 0 && poseTrait == 1 && rhandTrait > 3) {
//             revert("Right hand item not valid for combination of group and pose.");
//         }

//         if (groupTrait == 0 && poseTrait == 2 && rhandTrait > 1) {
//             revert("Right hand item not valid for combination of group and pose.");
//         }

//         if (groupTrait == 1 && poseTrait == 2 && rhandTrait > 4) {
//             revert("Right hand item not valid for combination of group and pose.");
//         }

//         if (groupTrait == 2 && poseTrait == 2 && rhandTrait > 4) {
//             revert("Right hand item not valid for combination of group and pose.");
//         }

//         if (groupTrait == 3 && poseTrait == 1 && rhandTrait > 6) {
//             revert("Right hand item not valid for combination of group and pose.");
//         }

//         if (groupTrait == 3 && poseTrait == 2 && rhandTrait > 3) {
//             revert("Right hand item not valid for combination of group and pose.");
//         }

//         if (groupTrait == 4 && poseTrait == 2 && rhandTrait > 3) {
//             revert("Right hand item not valid for combination of group and pose.");
//         }

//         // traits validation
//         require(groupTrait <= 4 && groupTrait >= 0, "Group trait not in required range.");
//         require(headTrait <= 38 && headTrait >= 0, "Head trait not in required range.");
//         require(chestTrait <= 18 && chestTrait >= 0, "Chest trait not in required range.");
//         require(legsTrait <= 14 && legsTrait >= 0, "Legs trait not in required range.");
//         require(bootsTrait <= 14 && bootsTrait >= 0, "Boots trait not in required range.");
//         require(lhandTrait <= 29 && lhandTrait >= 0, "Left hand trait not in required range.");
//         require(backgroundTrait <= 10 && backgroundTrait >= 0, "Background trait not in required range.");
//         require(rhandTrait <= 7 && rhandTrait >= 0, "Right hand trait not in required range.");
//         require(poseTrait <= 2 && poseTrait >= 0, "Pose trait not in required range.");
//         require(faceTrait <= 1 && faceTrait >= 0, "Face trait not in required range.");
//         require(accessoriesTrait <= 9 && accessoriesTrait >= 0, "Accessories trait not in required range.");

//         groupMap[groupTrait]++;
//         headMap[headTrait]++;
//         chestMap[chestTrait]++;
//         legsMap[legsTrait]++;
//         bootsMap[bootsTrait]++;
//         handMap[lhandTrait]++;
//         backgroundMap[backgroundTrait]++;
//         accessoriesMap[accessoriesTrait]++;

//         tokenTraits[tokenId] = bytes8(traits);
//         existingCombinations[traits] = 1;

//         walletToToken[msg.sender] = tokenId;
//     }

//     // Internal trait decoding

//     function groupTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & groupMask) >> 39);
//     }

//     function founderTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & founderMask) >> 38);
//     }

//     function backgroundTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & backgroundMask) >> 34);
//     }

//     function headTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & headMask) >> 28);
//     }

//     function faceTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & faceMask) >> 27);
//     }

//     function chestTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & chestMask) >> 22);
//     }

//     function poseTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & poseMask) >> 20);
//     }

//     function legsTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & legsMask) >> 16);
//     }

//     function bootsTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & bootsMask) >> 12);
//     }

//     function accessoriesTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & accessoriesMask) >> 8);
//     }

//     function lhandTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & lHandMask) >> 3);
//     }

//     function rhandTraitIndex(uint64 traits) internal view returns (uint64) {
//         return uint64((bytes8(traits) & rHandMask));
//     }
// }