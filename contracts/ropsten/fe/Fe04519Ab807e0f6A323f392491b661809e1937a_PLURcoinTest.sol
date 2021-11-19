// contracts/PLURcoin.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/ownable.sol";

contract PLURcoinTest is ERC20, Ownable {
    constructor() ERC20("PLURcoinTest", "PLUR") {
        _mint(msg.sender, 100000000000 * 10 ** 18);
    
    }

    function burn(uint256 amount) external {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _burn(msg.sender, amount);
        
    }
}