//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract YonMoon is ERC20 {
    using SafeMath for uint256;

    //fees
    uint256 TAX_FEE = 5;
    uint256 BURN_FEE = 5;

    address public owner;

    mapping(address => bool) public excludedFromTax;

    constructor() ERC20("CODETOKEN1", "CODE1") {
        _mint(msg.sender, 1000 * 10**18);
        owner = msg.sender;
        //include owner in excluded
        excludedFromTax[msg.sender] = true;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        if (excludedFromTax[msg.sender] == true) {
            _transfer(msg.sender, recipient, amount);
        } else {
            uint256 burnAmount = amount.mul(BURN_FEE) / 100;
            uint256 adminAmount = amount.mul(TAX_FEE) / 100;
            _burn(_msgSender(), burnAmount);
            _transfer(_msgSender(), owner, adminAmount);
            _transfer(
                _msgSender(),
                recipient,
                amount.sub(burnAmount).sub(adminAmount)
            );
        }
        return true;
    }
}