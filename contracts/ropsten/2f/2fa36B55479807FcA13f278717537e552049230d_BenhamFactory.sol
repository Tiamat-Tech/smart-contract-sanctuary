// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract BenhamFactory is Ownable, ReentrancyGuard, ERC721Enumerable {
    using SafeMath for uint256;

   uint256 public constant MAX_SUPPLY = 1000;
   uint256 public constant MAX_MINT = 10;
   uint256 public constant PRICE = 0.1 ether;
   uint256 public Max_Supply_T;

   bool public saleOpen = false;


    constructor() ERC721("Benham Factory", "BxF") {}
    
    /**
    * @dev onlyOwner Functions 
    */
    
    function withdraw() public onlyOwner {
        uint256 value = address(this).balance;
        sendValueTo(msg.sender, value);
    }
    
    function launchSale() public onlyOwner {
        saleOpen = !saleOpen;
    }
    
    
    /**
    * @dev Using nonReentrant prevent the contract to call himself 
    * Verify every statement required for the purchase 
    * Then implements token existing numbers and call the mint function 
    */   
    
    function purchase(uint256 numberOfTokens) public payable nonReentrant {
    require(saleOpen, "Contract is not active");
    require(totalSupply().add(numberOfTokens) <= MAX_SUPPLY, "Sale not active yet !");
    require(numberOfTokens > 0 && numberOfTokens <= MAX_MINT, "Already minted all !");
    require( msg.value >= PRICE.mul(numberOfTokens),"Ether value sent is not correct !");
    require(msg.value / numberOfTokens == PRICE, "Mint value is not good !");

    for (uint256 i = 0; i < numberOfTokens; i++) {
        if (Max_Supply_T < MAX_SUPPLY) {
            uint256 tokenId = Max_Supply_T;
            Max_Supply_T += 1;
            _safeMint(msg.sender, tokenId);
            }
        }
    }

    /**
    * @dev Send value to address
    */
    function sendValueTo(address to_, uint256 value) internal {
        address payable to = payable(to_);
        (bool success, ) = to.call{value: value}("");
        require(success, "Transfer failed.");
    }
    
    function tokensOfOwner(address _owner) external view returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
    
}