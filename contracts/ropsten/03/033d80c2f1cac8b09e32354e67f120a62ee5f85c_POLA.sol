//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.1;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract POLA is ERC20('Polkalaunch', 'POLA') , Ownable {
    mapping(address => bool) public minter;
    bool public finishMint = false;
    constructor() public {
        _mint(msg.sender, 300000000000000000000000000);
    }
    modifier onlyMinter() {
        require(minter[msg.sender] == true, "POLA: You Are Not A Minter");
        require(finishMint == false, "POLA: Finish Minting");
        _;
    }
    function removeMinter(address _address) onlyOwner public {
        minter[_address] = false;
    }
    function addMinter(address _address) onlyOwner public {
        minter[_address] = true;
    }
    function finishMinting() onlyOwner public {
        finishMint = true;
    }

    function mint(address _address,uint256 _amount) onlyMinter public {
        _mint(_address, _amount);
    } 
}