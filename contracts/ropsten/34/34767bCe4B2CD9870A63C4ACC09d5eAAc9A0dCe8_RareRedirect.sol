/*
 *
 *
                                                             
                                                             
                                                             
888d888 8888b.  888d888 .d88b.                               
888P"      "88b 888P"  d8P  Y8b                              
888    .d888888 888    88888888                              
888    888  888 888    Y8b.                                  
888    "Y888888 888     "Y8888                               
                                                             
                                                             
                                                             
                     888 d8b                          888    
                     888 Y8P                          888    
                     888                              888    
888d888 .d88b.   .d88888 888 888d888 .d88b.   .d8888b 888888 
888P"  d8P  Y8b d88" 888 888 888P"  d8P  Y8b d88P"    888    
888    88888888 888  888 888 888    88888888 888      888    
888    Y8b.     Y88b 888 888 888    Y8b.     Y88b.    Y88b.  
888     "Y8888   "Y88888 888 888     "Y8888   "Y8888P  "Y888 
                                                             


 This contract is unaudited. It's basically a ponzi.
 It's worse than a ponzi. It's definitely not "trustless".
 DNS is centralized. I'll change the URL if I deem it
 harmful/illegal/etc. No guarantees, no refunds.                                                          



 *
 *
 */

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RareRedirect is Ownable {
    // minimum price required to change the `currentURL`
    uint256 public priceFloor;
    // current URL where site will be redirected
    string currentURL = "";

    event urlChange(string currentURL);
    event priceFloorChange(uint256 priceFloor);

    function getUrl() public view returns (string memory) {
        return currentURL;
    }

    function setUrl(string memory newURL)
        external
        payable
        returns (string memory)
    {
        require(
            msg.value > priceFloor,
            "Value must be greater than priceFloor"
        );
        currentURL = newURL;
        priceFloor = msg.value;

        emit urlChange(currentURL);
        emit priceFloorChange(priceFloor);
        return currentURL;
    }

    function setUrlForOwner(string memory ownerUrl)
        public
        onlyOwner
        returns (string memory)
    {
        currentURL = ownerUrl;

        emit urlChange(currentURL);
        return currentURL;
    }

    function getPriceFloor() public view returns (uint256) {
        return priceFloor;
    }

    function withdrawAll() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}