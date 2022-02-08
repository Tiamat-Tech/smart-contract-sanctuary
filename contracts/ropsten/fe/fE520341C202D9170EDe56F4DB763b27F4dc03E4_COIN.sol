//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract COIN is ERC20("COINX","X"){

    address[] userList;
    constructor() {
    }

    function addUser(address payable newUser) public {
        console.log("Adding User", newUser);
        userList.push(newUser);
    }

    function listUser() public view returns (address[] memory user){
        user = userList;
        return user;
    }

    function mintToAll() public {
        console.log("---Mint To All");
        for (uint256 i=0;i<userList.length;i++){
            console.log(userList[i]);
            _mint(userList[i], 100);
        }
    }
}