// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// ZetaBar is the coolest bar in town. You come in with some Zeta, and leave with more! The longer you stay, the more Zeta you get.
//
// This contract handles swapping to and from xZeta, ZetaSwap's staking token.
contract ZetaBar is ERC20("ZetaBar", "xZETA"){
    using SafeMath for uint256;
    IERC20 public zeta;

    // Define the Zeta token contract
    constructor(IERC20 _zeta) public {
        zeta = _zeta;
    }

    // Enter the bar. Pay some ZETAs. Earn some shares.
    // Locks Zeta and mints xZeta
    function enter(uint256 _amount) public {
        // Gets the amount of Zeta locked in the contract
        uint256 totalZeta = zeta.balanceOf(address(this));
        // Gets the amount of xZeta in existence
        uint256 totalShares = totalSupply();
        // If no xZeta exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalZeta == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xZeta the Zeta is worth. The ratio will change overtime, as xZeta is burned/minted and Zeta deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalZeta);
            _mint(msg.sender, what);
        }
        // Lock the Zeta in the contract
        zeta.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your ZETAs.
    // Unlocks the staked + gained Zeta and burns xZeta
    function leave(uint256 _share) public {
        // Gets the amount of xZeta in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Zeta the xZeta is worth
        uint256 what = _share.mul(zeta.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        zeta.transfer(msg.sender, what);
    }
}