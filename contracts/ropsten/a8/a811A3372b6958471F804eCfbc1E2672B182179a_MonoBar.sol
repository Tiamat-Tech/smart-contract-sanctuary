// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// MonoBar is the coolest bar in town. You come in with some Mono, and leave with more! The longer you stay, the more Mono you get.
//
// This contract handles swapping to and from sMONO, MonoSwap's staking token.
contract MonoBar is ERC20("MonoBar", "sMONO"){
    using SafeMath for uint256;
    IERC20 public mono;

    // Define the Mono token contract
    constructor(IERC20 _mono) public {
        mono = _mono;
    }

    // Enter the bar. Pay some MONOs. Earn some shares.
    // Locks Mono and mints sMONO
    function enter(uint256 _amount) public {
        // Gets the amount of Mono locked in the contract
        uint256 totalMono = mono.balanceOf(address(this));
        // Gets the amount of sMONO in existence
        uint256 totalShares = totalSupply();
        // If no sMONO exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalMono == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of sMONO the Mono is worth. The ratio will change overtime, as sMONO is burned/minted and Mono deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalMono);
            _mint(msg.sender, what);
        }
        // Lock the Mono in the contract
        mono.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your Monos.
    // Unlocks the staked + gained Mono and burns sMONO
    function leave(uint256 _share) public {
        // Gets the amount of sMONO in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Mono the sMONO is worth
        uint256 what = _share.mul(mono.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        mono.transfer(msg.sender, what);
    }
}