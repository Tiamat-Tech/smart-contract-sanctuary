// SPDX-License-Identifier: MIT

/*                                                                                                        
_|                                                                              _|                      
_|  _|    _|    _|  _|  _|_|    _|_|          _|_|_|    _|_|    _|_|_|  _|_|          _|_|_|    _|_|_|  
_|_|      _|    _|  _|_|      _|    _|      _|        _|    _|  _|    _|    _|  _|  _|        _|_|      
_|  _|    _|    _|  _|        _|    _|      _|        _|    _|  _|    _|    _|  _|  _|            _|_|  
_|    _|    _|_|_|  _|          _|_|          _|_|_|    _|_|    _|    _|    _|  _|    _|_|_|  _|_|_|    

UNLIMITED KOMIC PASS  

Total Supply:1,111
11 Reserved for founders                                                                                                                          

https://kurocomics.com
*/

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract KomicPass is ERC1155, Ownable {
    using SafeMath for uint256;

    uint256 tokenId = 0;
    uint256 amountMinted = 0;
    uint256 limitAmount = 1111;
    uint256 private tokenPrice = 250000000000000000; // 0.25 ETH
                                
    bool publicSale = false;
    
    constructor() ERC1155("ipfs://QmQqMF7izNAaU9CY3qV9ZGs4Aksv6ywjx8261khgzQbReW") {
     
    }
	// Check if contracts are trying to mint
    modifier callerIsUser() {
      require(tx.origin == msg.sender, "The caller is another contract");
      _;
    }

    // Mint function
    function mint(uint256 amountToMint) public payable callerIsUser returns(uint256) {
        // By calling this function, you agreed that you have understood the risks involved with using smart this contract.
        require(publicSale == true, "Sales have not started");
        uint256 amount = amountToMint;

        // Public sale is active when bool publicSale is true 

        // If public sales is active
        if(publicSale == true)
            require(amount <= 3 && amount >= 1, "You have to mint between 1 to 3 at a time");

        // Add verification on ether required to pay
        require(msg.value >= tokenPrice.mul(amount), "Not enough money");
        
        uint256 prevTokenId = tokenId;
        // Increment tokenId 
        tokenId++;
        // Check max tokens have not been reached
        require(amount + amountMinted <= limitAmount, "Max supply reached");
        amountMinted = amountMinted + amount;
        //Mint KomicPass
        _mint(msg.sender, tokenId, amount, "");
        return prevTokenId;
    }
    
    // Dev mint function
    function devMint(uint256 devAmount) public onlyOwner {
        tokenId++;
        require(devAmount + amountMinted <= limitAmount, "Max supply reached");
        amountMinted = amountMinted + devAmount;
        _mint(msg.sender, tokenId, devAmount, "");
    }
    
    // Toggle public sales
    function togglePublicSales() public onlyOwner {
        publicSale = !publicSale;
    }
    
    // Get the price of the token
    function getPrice() view public returns(uint256) { 
        return tokenPrice;
    }
    
    // Get amount minted
    function getAmountMinted() view public returns(uint256) {
        return amountMinted;
    }
    
    // Change Sale Price
    function setPrice(uint256 _newPrice) public onlyOwner {
        tokenPrice = _newPrice;
    }
    
    // Basic withdrawal of funds function in order to transfert ETH out of the smart contract
    function withdrawFunds() public onlyOwner {
		payable(msg.sender).transfer(address(this).balance);
	}
}