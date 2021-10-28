// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

interface FInterface {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function balanceOf(address owner) external view returns (uint256 balance);
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256 tokenId);
}

contract BaseAnimal is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    uint256 public PROVENANCE;
    bool public isHatchingActive = false;
    bool public isBurningActive = false;

    address public fAddress = 0x87db4A58A350E734a924556E66C451C164144431;
    FInterface fContract = FInterface(fAddress);

    string private _baseURILink;
    
    // Keep track of animals burned
    mapping(uint256 => uint256) public _animalsBurned;
    
    event hatched(uint tokenId, address toAddress, address contractAddress);
    event burned(uint tokenId, address burnersAddress);

    constructor() ERC721("Base Animal", "ANML") {
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory baseURI) external onlyOwner() {
        _baseURILink = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURILink;
    }

    function flipHatchingState() public onlyOwner {
        isHatchingActive = !isHatchingActive;
    }
    
    function flipBurningState() public onlyOwner {
        isBurningActive = !isBurningActive;
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
    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }
    
    function setProvenance(string memory rate) public onlyOwner {
        PROVENANCE = random(string(abi.encodePacked('BaseAnimals', rate))) % 7000;
    }
    
    function _setValidAnimal(uint tokenId) internal {
        
    }
    
    function directMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
    
    
    function getAddress() public view returns (address) {
        return address(this);   
    }
    
    function isAnimalBurned(uint tokenId) public view returns (bool) {
        return (_animalsBurned[tokenId] == tokenId);
    }
    
    function burnAnimal(uint tokenId) external {
        require(isAnimalBurned(tokenId), "Burning must be active to burn");
        require(balanceOf(msg.sender) > 0, "Must own an animal to burn");
        require(ownerOf(tokenId) == msg.sender, "Must own an animal to burn");
        
        _burn(tokenId);
        _animalsBurned[tokenId];
        emit burned(tokenId, msg.sender);
    }
    
    /*
    function isHatched(uint tokenId) public view returns (bool) {
        require(isHatchingActive, "Hatching is not yet active. Therefore, no animals have been hatched");
        //bool hatched = false;
        
        return false;
    }
    */
    
    function setApproval() external {
        IERC721(fAddress).setApprovalForAll(address(this), true);
    }
    
    function hatchEgg(uint tokenId) public {
        require(isHatchingActive, "Hatching must be active to hatch");
        require(!_exists(tokenId), "Egg is already hatched");
        require(fContract.balanceOf(msg.sender) > 0, "Must own an Egg to hatch");
        require(fContract.ownerOf(tokenId) == msg.sender, "You do not own the Egg you are trying to hatch");
        
        // approve this egg for hatching
        //IERC721(fAddress).setApprovalForAll(address(this), true);
        //IERC721(fAddress).approve(address(this), tokenId);
        // egg has been hatched... (sent to null address)
        IERC721(fAddress).safeTransferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, tokenId);
        
        // mint the hatched based animal
        _safeMint(msg.sender, tokenId);
        
        //_setValidAnimal(tokenId);
        
        emit hatched(tokenId, msg.sender, fAddress);
    }
    
}