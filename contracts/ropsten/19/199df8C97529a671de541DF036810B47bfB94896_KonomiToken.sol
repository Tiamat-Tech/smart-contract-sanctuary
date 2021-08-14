// https://etherscan.io/address/0x850aAB69f0e0171A9a49dB8BE3E71351c8247Df4#code
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract KonomiToken is ERC20 {
    constructor() ERC20("Konomi", "KONO") {
        _mint(msg.sender, 100000000 * 10**uint256(decimals()));
    }
}