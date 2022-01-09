//"SPDX-License-Identifier: MIT"

pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract JusticeToken is ERC20, Ownable {

    event ReturnedERC20(address indexed token, address indexed receiver, uint amount);

    constructor(uint _totalSupply) ERC20("Justice Token", "JTK") {
        _mint(msg.sender, _totalSupply);
    }

    function burn(uint _amount) external returns(bool success) {
        
        _burn(msg.sender, _amount);
        return true;
    }
}