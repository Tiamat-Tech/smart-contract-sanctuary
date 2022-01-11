// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, Ownable {
    string public constant _name = "Test Token";
    string public constant _symbol = "Test Token";
    //uint256 public _initialSupply = 8e9 * (10 ** decimals());

    //_mint(_msgSender(), _initialSupply);
    constructor() ERC20(_name, _symbol) {}

    function mint(address recipient, uint256 amount) external {
        require(recipient != address(0), "invalid recipient address");
        _mint(recipient, amount);
    }
    
}