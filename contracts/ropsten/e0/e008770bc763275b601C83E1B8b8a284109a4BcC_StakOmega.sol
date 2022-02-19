// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// StakOmega is the coolest pit in town. You come in with some Omega, and leave with more! The longer you stay, the more Omega you get.
//
// This contract handles swapping to and from xOmega, EdenSwap's staking token.
contract StakOmega is ERC20("tOmega Staked Omega EdenSwap", "tOmega"){
    using SafeMath for uint256;

    IERC20 public immutable Omega;

    // Define the Omega token contract
    constructor(IERC20 _Omega) {
        require(address(_Omega) != address(0), "_Omega is a zero address");
        Omega = _Omega;
    }

    // Enter the Edenhouse. Pay some Omegas. Earn some shares.
    // Locks Omega and mints tOmega
    function enter(uint256 _amount) public {
        // Gets the amount of Omega locked in the contract
        uint256 totalOmega = Omega.balanceOf(address(this));
        // Gets the amount of tOmega in existence
        uint256 totalShares = totalSupply();
        // If no tOmega exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalOmega == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of tOmega the Omega is worth. The ratio will change overtime, as tOmega is burned/minted and Omega deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalOmega);
            _mint(msg.sender, what);
        }
        // Lock the Omega in the contract
        Omega.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the doghouse. Claim back your Omegas.
    // Unclocks the staked + gained Omega and burns tOmega
    function leave(uint256 _share) public {
        // Gets the amount of xOmega in existence
        uint256 totalShares = totalSupply();

        // Calculates the amount of Omega the xOmega is worth
        uint256 what = _share.mul(Omega.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        Omega.transfer(msg.sender, what);
    }
}