// contracts/RugToken.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/presets/ERC20PresetFixedSupply.sol";

contract RugToken is ERC20Burnable {
     constructor ()
        ERC20("RugToken", "RUG")
        public {
            _mint(msg.sender, 30000000*(10**18));
    }
}