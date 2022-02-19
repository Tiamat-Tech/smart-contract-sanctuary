// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// StakPara is the coolest pit in town. You come in with some Para, and leave with more! The longer you stay, the more Para you get.
//
// This contract handles swapping to and from xPara, EdenSwap's staking token.
contract StakPara is ERC20("tPara Staked Para EdenSwap", "tPara"){
    using SafeMath for uint256;

    IERC20 public immutable Para;

    // Define the Para token contract
    constructor(IERC20 _Para) {
        require(address(_Para) != address(0), "_Para is a zero address");
        Para = _Para;
    }

    // Enter the Edenhouse. Pay some Paras. Earn some shares.
    // Locks Para and mints tPara
    function enter(uint256 _amount) public {
        // Gets the amount of Para locked in the contract
        uint256 totalPara = Para.balanceOf(address(this));
        // Gets the amount of tPara in existence
        uint256 totalShares = totalSupply();
        // If no tPara exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalPara == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of tPara the Para is worth. The ratio will change overtime, as tPara is burned/minted and Para deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalPara);
            _mint(msg.sender, what);
        }
        // Lock the Para in the contract
        Para.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the doghouse. Claim back your Paras.
    // Unclocks the staked + gained Para and burns tPara
    function leave(uint256 _share) public {
        // Gets the amount of xPara in existence
        uint256 totalShares = totalSupply();

        // Calculates the amount of Para the xPara is worth
        uint256 what = _share.mul(Para.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        Para.transfer(msg.sender, what);
    }
}