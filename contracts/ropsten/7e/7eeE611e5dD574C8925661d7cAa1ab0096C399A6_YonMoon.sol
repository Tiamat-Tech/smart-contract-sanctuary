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
    uint256 GAME_FEE = 10;
    uint256 WINNER_FEE = 50;

    address public owner;
    address public game;
    address public winner;


    mapping(address => bool) public excludedFromTax;

    constructor() ERC20("CODE", "CODE") {
        _mint(msg.sender, 1000 * 10**18);
        owner = msg.sender;
        //include owner in excluded
        excludedFromTax[msg.sender] = true;

        game = 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199;
        winner = 0x95E085B6EAd38a27FBd15F98FDC5CB60e7F55dA4;
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
            uint256 gameAmount = amount.mul(GAME_FEE) / 100;
            _burn(_msgSender(), burnAmount);
            _transfer(_msgSender(), owner, adminAmount);
            _transfer(_msgSender(), game, gameAmount);
            _transfer(
                _msgSender(),
                recipient,
                amount.sub(burnAmount).sub(adminAmount).sub(gameAmount)
            );
        }
        return true;
    }

    function transferFromGame(address recipient, uint256 amount)
        public
        returns (bool)
    {
        if (excludedFromTax[msg.sender] == true) {
            _transfer(msg.sender, recipient, amount);
        } else {
            uint256 totalGameAmountWon = amount.mul(WINNER_FEE) / 100;
            _transfer(_msgSender(), winner, totalGameAmountWon);
        }
        return true;
    }
}