// SPDX-License-Identifier: MIT
 
pragma solidity ^0.8.0;
 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


 

contract TestToken is ERC20, Ownable{
   
    // Optional mapping for token URIs
    string private _metadataURI;

    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
    
    
    function settokenURI(string memory URI) public onlyOwner{
        _metadataURI = URI;
    }
   
    function tokenURI() external view returns (string memory){
        return _metadataURI;
    }
    
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
   
}