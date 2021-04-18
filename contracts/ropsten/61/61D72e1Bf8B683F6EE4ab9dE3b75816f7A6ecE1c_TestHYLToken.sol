// SPDX-Licence-Identifier: MIT
pragma solidity ^0.6.12;

import "./openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestHYLToken is ERC20 {
    using SafeMath for uint256;
    uint public INITIAL_SUPPLY = 100000000 * 10 ** 18;

    constructor() public ERC20("THYLT", "THYLT") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}