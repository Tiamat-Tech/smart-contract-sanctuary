// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MyToken is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;

    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 0 * 10 ** decimals());
    }
    
    uint256 public altSupply = 2000000000;

   // Total Supplies of Token
    uint256 public circularSupply = altSupply.div(100).mul(60);
    uint256 public privateSupply = altSupply.div(100).mul(40);
    
    // Token Distribution
    uint256 public _investorsPercentage  = circularSupply.div(100).mul(40);
    uint256 public _rewardsPercentage    = circularSupply.div(100).mul(30);
    uint256 public _artistsPercentage    = circularSupply.div(100).mul(15);   
    uint256 public _foundersPercentage   = circularSupply.div(100).mul(9);
    uint256 public _developersPercentage = circularSupply.div(100).mul(6);
    

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    

    function transferCircularFunds(address[] memory recipients, uint256[] memory values) public onlyOwner {
      for (uint256 i = 0; i < recipients.length; i++) {
        values[i] = SafeMath.mul(values[i], 1 ether);
        require(circularSupply >= values[i], 'Circular Supply is less then your values');
        circularSupply = SafeMath.sub(circularSupply,values[i], 'error in line 39');
        _mint(recipients[i], values[i]); 
    }
    
  }
  
    function investorsPercentage(address[] memory recipients, uint256[] memory values) public onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            values[i] = SafeMath.mul(values[i], 1 ether);
            require(_investorsPercentage >= values[i]);
            _investorsPercentage = SafeMath.sub(_investorsPercentage, values[i]);
            _mint(recipients[i], values[i]);
            
        }
        
    }

    
}