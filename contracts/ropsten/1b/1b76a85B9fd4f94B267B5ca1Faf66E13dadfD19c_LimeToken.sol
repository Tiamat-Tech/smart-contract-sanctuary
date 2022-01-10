// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.0;
pragma abicoder v2;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract LimeToken is ERC20 {
    
    constructor() ERC20("LimeToken", "LMT") {

    }
    
    function burn(
        address account,
        uint256 amount
    ) public 
      virtual
    {
        _burn(account, amount);
    }

}