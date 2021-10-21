// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/access/Ownable.sol";

// SOULBar is the coolest bar in town. You come in with some SOUL, and leave with more! The longer you stay, the more SOUL you get.
//
// This contract handles swapping to and from xSOUL.
contract SOULBar is ERC20("SOULBar", "xSOUL"),Ownable{
    using SafeMath for uint256;
    IERC20 public soul;
    
    uint256 public burnFee =33;
    uint256 public transferFee =33*10**7;

    // Sender addresses excluded from Tax
    mapping(address => bool) public excludedAddresses;
    uint public totalFees;
    // Define the soul token contract
    constructor(IERC20 _soul) public {
        _mint(msg.sender, 1000);
        soul = _soul;
    }

    function isAddressExcluded(address _address) public view returns (bool) {
        return excludedAddresses[_address];
    }


    function excludeAddress(address _address) public onlyOwner returns (bool) {
        require(!excludedAddresses[_address], "address can't be excluded");
        excludedAddresses[_address] = true;
        return true;
    }

    function includeAddress(address _address) public onlyOwner returns (bool) {
        require(excludedAddresses[_address], "address can't be included");
        excludedAddresses[_address] = false;
        return true;
    }
    
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (excludedAddresses[msg.sender]) {
            _transfer(msg.sender, recipient, amount);
        } else {
            // If not excluded from fee
            uint256 burn = amount.mul(burnFee).div(10000);
            
             _transfer(msg.sender, 0x0111011001100001011011000111010101100101, burn);
            
            //uint256 trenafer = amount.mul(transferFee).div(100);
            
            uint256 amountAfterFee =  amount.sub(burn);
            
            
            _transfer(msg.sender, recipient, amountAfterFee);
            
            // _transferWithTax(sender, recipient, amount, burnTax);
        }
        
        return true;
    }

    // Enter the bar. Pay some SOULs. Earn some shares.
    // Locks SOUL and mints xSoul
    function enter(uint256 _amount) public {
        // Gets the amount of SOUL locked in the contract
        uint256 totalSoul = soul.balanceOf(address(this));
        // Gets the amount of xSoul in existence
        uint256 totalShares = totalSupply();
        // If no xSoul exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalSoul == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xSoul the SOUL is worth. The ratio will change overtime, as xSoul is burned/minted and SOUL deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalSoul);
            _mint(msg.sender, what);
        }
        // Lock the SOUL in the contract
        soul.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your SOULs.
    // Unlocks the staked + gained SOUL and burns xSoul
    function leave(uint256 _share) public {
        // Gets the amount of xSoul in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of SOUL the xSoul is worth
        uint256 what = _share.mul(soul.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        soul.transfer(msg.sender, what);
    }
}