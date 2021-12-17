//SPFX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Saitama is ERC20 {

    constructor() ERC20("Saitama Inu","SAITAMA"){
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}