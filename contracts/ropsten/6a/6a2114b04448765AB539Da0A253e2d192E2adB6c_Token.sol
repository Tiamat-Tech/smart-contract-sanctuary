// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0-solc-0.7/contracts/token/ERC20/ERC20.sol";


contract Token is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {
        _mint(msg.sender, 1000000000 * (10 ** uint256(decimals())));
    }
    
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}