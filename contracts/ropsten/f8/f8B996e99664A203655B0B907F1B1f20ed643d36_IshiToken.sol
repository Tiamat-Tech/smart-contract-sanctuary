//SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IshiToken is ERC20 , ERC20Burnable , Pausable , Ownable{
     constructor() ERC20("IshiToken", "ISH") {
        _mint(msg.sender, 100000000 * 10**18);
        _burn(msg.sender, 1000000 * 10**18);
    }
   

  
  function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
  }
  
  function burn(address to, uint256 amount) public onlyOwner{
      _burn(to, amount);
  }
  
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
     function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
   
     {
        super._beforeTokenTransfer(from, to, amount);
    }
}