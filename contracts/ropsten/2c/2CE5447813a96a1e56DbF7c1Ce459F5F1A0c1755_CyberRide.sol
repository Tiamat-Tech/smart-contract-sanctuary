// SPDX-License-Identifier: MIT

// File: contracts/CyberRide.sol


pragma solidity ^0.8.0;


/**
*    ______      __              ____  _     __   
*   / ____/_  __/ /_  ___  _____/ __ \(_)___/ /__ 
*  / /   / / / / __ \/ _ \/ ___/ /_/ / / __  / _ \
* / /___/ /_/ / /_/ /  __/ /  / _, _/ / /_/ /  __/
* \____/\__, /_.___/\___/_/  /_/ |_/_/\__,_/\___/ 
*      /____/    
*/
/**
 * The CyberRide Gen-1: 
 * 9,999 unique 3D voxel rides designed to be your first ride in the Metaverse.
 * 
 * visit cyberride.io for details. 
 * */


import "ERC721.sol";
import "Ownable.sol";
import "ERC721Enumerable.sol";


/**
 * @title CyberRide contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract CyberRide is ERC721, ERC721Enumerable, Ownable {


    //provenance hash calculated before deploying smart contract to ensure fairness, see cyberride.io for more detials
    string public PROVENANCE = "44f19273ec4a41dfa524e5781200f2f6f9e1562131e6e14606f743a13d37c732";

    uint256 public startingIndexBlock;

    uint256 public startingIndex;

    uint256 public publicSalePrice = 0.1 ether; //0.1 ETH

    uint256 public allowListPrice = 0.08 ether; //0.08 ETH

    uint public constant maxRidePurchase = 10;

    uint256 public constant MAX_RIDES = 9999;

    bool public saleIsActive = false;

    bool public isAllowListActive = false;

    string private _baseURIextended;

    mapping(address => uint8) private _allowList;


    constructor() ERC721('CrTesting Gen-1', 'CBTS') {
        
        
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }



    /**
     * Reserve rides for future development and collabs
     */
    function reserveRides(uint256 numberOfTokens) external onlyOwner {
        uint256 supply = totalSupply();
        require(supply + numberOfTokens <= MAX_RIDES, "Reserve amount would exceed max tokens");
        uint256 i;
        for (i = 0; i <numberOfTokens; i++) {
            _mint(msg.sender, supply + i);
        }
    }

    
  

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }


    /*
    *  Set Public Sale State
    */
    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }


    /*
    */
    function setPublicSalePrice(uint256 newSalePrice) public onlyOwner {
        publicSalePrice = newSalePrice;
    }


    /*
    */
    function setAllowlistSalePrice(uint256 newSalePrice) public onlyOwner {
        allowListPrice = newSalePrice;
    }


    /*
    * set if allow list is active  
    */
    function setIsAllowListActive(bool _isAllowListActive) external onlyOwner {
        isAllowListActive = _isAllowListActive;
    }

    function setAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _allowList[addresses[i]] = 2;
        }
    }


    function numAvailableToMint(address addr) external view returns (uint8) {
        return _allowList[addr];
    }

    /**
    * Mints CyberRide base on number of tokens
    */
    function mintAllowList(uint8 numberOfTokens) external payable {
        uint256 supply = totalSupply();
        require(isAllowListActive, "Allow list is not active");
        require(numberOfTokens <= _allowList[msg.sender], "Exceeded max available to purchase");
        require(supply + numberOfTokens <= MAX_RIDES, "Purchase would exceed max tokens");
        require(allowListPrice *numberOfTokens <= msg.value, "Ether value sent is not correct");
        require(msg.sender == tx.origin, "Only real users minting are supported");
        
        _allowList[msg.sender] -= numberOfTokens;


        // set starting index block if it is the first mint
        if (startingIndexBlock==0 && supply==0) {
            startingIndexBlock = block.number;
        } 

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }


    /**
    * Mints CyberRide base on number of tokens
    */
    function mintRide(uint numberOfTokens) public payable {
        uint256 supply = totalSupply();
        require(saleIsActive, "Sale must be active to mint a CyberRide");
        require(numberOfTokens <= maxRidePurchase, "Can only mint 10 rides at a time");
        require(supply + numberOfTokens <= MAX_RIDES, "Purchase would exceed max supply of CyberRide Gen-1");
        require(publicSalePrice * numberOfTokens <= msg.value, "Ether value sent is not correct");
        require(msg.sender == tx.origin, "Only real users minting are supported");
     

        for(uint i = 0; i < numberOfTokens; i++) {
             _safeMint(msg.sender, supply + i);
        }
        
    }

    /**
     * Set the starting index for the collection
     */
    function setStartingIndex() public onlyOwner {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");
        
        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_RIDES;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number-startingIndexBlock > 255) {
            startingIndex = uint(blockhash(block.number - 1)) % MAX_RIDES;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex+1;
        }
    }

    /**
     * Set the starting index block for the collection, essentially unblocking
     * setting starting index
     */
    function emergencySetStartingIndexBlock() public onlyOwner {
        require(startingIndex == 0, "Starting index is already set");
        startingIndexBlock = block.number;
    }



    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

}