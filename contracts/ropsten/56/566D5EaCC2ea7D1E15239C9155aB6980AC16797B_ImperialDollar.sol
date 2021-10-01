//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ImperialDollar is ERC20{

    address public owner;

       constructor(string memory name, string memory symbol) ERC20(name, symbol) {
           owner = _msgSender();
        }

     function mint(address _address , uint256 value) public {
         _mint(_address,value);
     }  

}