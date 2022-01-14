//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract AvatarPack is ERC721Upgradeable {
    // string private greeting;

    function initialize() initializer public {
        __ERC721_init("Basic Avatar Pack", "JAVT");
    }


    function greet() public view returns (string memory) {
        // return greeting;
    }

    function setGreeting(string memory _greeting) public {
        // console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        // greeting = _greeting;
    }
}