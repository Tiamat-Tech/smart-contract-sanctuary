//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import {ERC20, ERC20Permit} from "./lib/ERC20Permit.sol";

contract UdpnUsdc is ERC20Permit {
   constructor(uint256 initialSupply) ERC20("UDPN-USDC","uUDPN") ERC20Permit("0.0.1") {
      _mint(msg.sender, initialSupply);
   }

   function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}