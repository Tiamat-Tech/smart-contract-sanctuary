// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PartnerCoin is ERC20("PartnerCoin", "PTNR") {
    constructor(address[] memory holders, uint256[] memory amounts) public {
        for (uint256 i = 0; i < holders.length; i++) {
            _mint(holders[i], amounts[i]);
        }
    }
}