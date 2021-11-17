// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardToken is ERC20 {
    address public admin;

    constructor () ERC20('NREWARD','NRWD'){

        _mint(msg.sender,500000 * 10 ** 9);
        admin=msg.sender;
    }
    
    function mint(address to, uint amount) external {    
        require(msg.sender== admin , 'only admin allowed');
         _mint(to,amount);
    }
    
    function burn(uint amount) external {
        _burn(msg.sender,amount);        
    }

    function decimals() public pure  override returns (uint8) {
        return 9;
    }
    
    }