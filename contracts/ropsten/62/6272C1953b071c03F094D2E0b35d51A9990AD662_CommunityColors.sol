//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CommunityColors is Ownable, ERC721 {
    
    bool locked = false;

    constructor() ERC721("Community Colors", "COLORS") {}

    function mintTheColor(address recipient, string memory tokenURI, uint256 _tokenId)
        public 
        payable
        returns (uint256)
    {
        
        require(
            totalSupply()  <= 16777216,
            "All colors have been minted."
        );
        
        require(_tokenId <=  16777216 && _tokenId >=1, "Not a valid color.");
        require(msg.value >=  0.01 ether, "Not enough ETH sent: check price.");
        require(!locked, "Reentrant call detected!");
        locked = true;
        uint256 newItemId =  _tokenId;
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        locked = false; 
        return newItemId;
    }


function withdraw() public onlyOwner{
            require(owner() == msg.sender, "Ownable: caller is not the owner");
            require(!locked, "Reentrant call detected!");
            locked = true;
            uint256 amount = address(this).balance;
            (bool success, ) = msg.sender.call{value:amount}("");            
            require(success, "Transfer failed.");
            locked = false;  
}
    
}