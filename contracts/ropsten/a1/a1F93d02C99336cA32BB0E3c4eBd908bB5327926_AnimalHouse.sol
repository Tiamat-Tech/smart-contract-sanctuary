// SPDX-License-Identifier: MIT
 
pragma solidity ^0.8.1;

import "openzeppelin-solidity/contracts/access/Ownable.sol";

abstract contract AbstractAnimalHouseEntity is Ownable {

    address internal _admin;

    /* modifiers */
    modifier onlyOwnerOrAdmin {
        if(_admin != address(0)){
            require(_msgSender() == owner() || _msgSender() == admin(), "AnimalHouse Entity: Sender is neither owner nor admin.");
        }
        else {
            require(_msgSender() == owner(),  "AnimalHouse Entity: Sender is not owner.");
        }
        _;
    }

    /* getter & setter for admin address */
    function admin() public view returns (address) {
        return _admin;
    }
    function setAdmin(address newAdmin) external onlyOwnerOrAdmin {
        require(newAdmin != address(0), "AnimalHouse Entity: Admin cannot be AddressZero");
        require(newAdmin != owner(), "AnimalHouse Entity: Owner and admin cannot be the same address.");
        _admin = newAdmin;
    }
}