// contracts/MyTokenV1.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyTokenV1 is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    function initialize() initializer public {
      __ERC20_init("tx0x1119", "txxx");
      __Ownable_init();

      _mint(msg.sender, 10000 * 10 ** decimals());
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

contract MyTokenV2 is MyTokenV1 {
    uint fee;

    function version() pure public returns (string memory){
        return "v2!";
    }
}

// contract MyTokenV3 is MyTokenV1 {
//     uint fee;
//     string tax;
    
//     function version() pure public returns (string memory){
//         return "v3!";
//     }

// }