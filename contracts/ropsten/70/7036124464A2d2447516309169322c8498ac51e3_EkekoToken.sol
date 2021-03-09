// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// SushiBar is the coolest bar in town. You come in with some EKKOs, and leave with more! The longer you stay, the more EKKOs you get.
//
// This contract handles swapping to and from xEKKOs, EkekoSwap's staking token.
contract EkekoBounty is ERC20("EkekoBounty", "xEKKO"){
    using SafeMath for uint256;
    IERC20 public ekeko;

    // Define the Sushi token contract
    constructor(IERC20 _ekeko) public {
        ekeko = _ekeko;
    }

    // Enter the bar. Pay some EKKOs. Earn some shares.
    // Locks EKKO and mints xEKKO
    function enter(uint256 _amount) public {
        // Gets the amount of EKKO locked in the contract
        uint256 totalEkeko = ekeko.balanceOf(address(this));
        // Gets the amount of xEKKO in existence
        uint256 totalShares = totalSupply();
        // If no xEKKO exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalEkeko == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xEKKOs the EKKO is worth. The ratio will change overtime, as xSushi is burned/minted and Sushi deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalEkeko);
            _mint(msg.sender, what);
        }
        // Lock the Sushi in the contract
        ekeko.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your EKKOs.
    // Unclocks the staked + gained Sushi and burns xEKKOs
    function leave(uint256 _share) public {
        // Gets the amount of xEKKO in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of EKKO the xEKKO is worth
        uint256 what = _share.mul(ekeko.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        ekeko.transfer(msg.sender, what);
    }
}