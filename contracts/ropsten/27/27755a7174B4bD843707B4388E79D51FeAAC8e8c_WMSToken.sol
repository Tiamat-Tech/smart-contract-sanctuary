//SPDX-License-Identifier: Unlicense

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WMSToken is ERC20 {
      constructor(uint256 _initialSupply, string memory _name, string memory _symbol) 
        ERC20(_name, _symbol) { //default decimal 18
            _mint(msg.sender, _initialSupply);
    }
}