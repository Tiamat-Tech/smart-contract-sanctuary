//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract ClassToken is ERC20PresetMinterPauser {
        constructor() ERC20PresetMinterPauser("ClassToken", "CLT") {
        _mint(msg.sender, 10000*1e18);
        }
}