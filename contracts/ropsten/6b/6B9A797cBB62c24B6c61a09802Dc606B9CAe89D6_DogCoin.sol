// SPDX-License-Identifier: MIT

// SOLIDITY-COVERAGE
// --------------|----------|----------|----------|----------|----------------|
// File          |  % Stmts | % Branch |  % Funcs |  % Lines |Uncovered Lines |
// --------------|----------|----------|----------|----------|----------------|
//  contracts/   |    97.22 |       70 |      100 |     97.3 |                |
//   DogCoin.sol |    97.22 |       70 |      100 |     97.3 |             99 |
// --------------|----------|----------|----------|----------|----------------|
// All files     |    97.22 |       70 |      100 |     97.3 |                |
// --------------|----------|----------|----------|----------|----------------|


pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract DogCoin is ERC20 {
    
    address[] public holders;
    
    
    event User_Removed(address user);
    event User_Added(address user);


    constructor() ERC20("DogCoin", "DC") {
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);

        bool address_found = false;
        
        for (uint i = 0; i < holders.length; i++) {
        
            if(holders[i] == to){

                address_found = true;

            }    
        }

        if (!address_found){

            holders.push(to);
            emit User_Added(to);

        }

    }

    function getHolders() public view returns (address[] memory) {
        
        return holders;

    }

    function _transfer(address from, address to, uint256 amount) internal virtual override{

        super._transfer(from, to, amount);

        bool address_found = false;
        
        for (uint i = 0; i < holders.length; i++) {

            if(holders[i] == from){

                if (balanceOf(from) == 0) {

                    holders[i] = holders[holders.length - 1];
                    holders.pop();
                    emit User_Removed(from);

                }

            }
        
            if(holders[i] == to){

                address_found = true;

            }    
        }

        if (!address_found){

            holders.push(to);
            emit User_Added(to);

        }
        
    }


}