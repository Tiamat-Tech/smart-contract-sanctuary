// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Stakeable.sol";

contract StakingToken is ERC20, Ownable, Stakeable {
    constructor(uint256 amount) ERC20("StakingToken", "STK") {
        mint(amount);
    }

    function mint(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount * 10**decimals());
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return (super.balanceOf(account) / 10**decimals());
    }

    function totalSupply() public view virtual override returns (uint256) {
        return (super.totalSupply() / 10**decimals());
    }

    function stake(uint256 _amount) public {
        require(
            _amount < balanceOf(msg.sender),
            "StakingToken: Cannot stake more than you own"
        );

        _stake(_amount * 10**decimals());
        _burn(msg.sender, _amount * 10**decimals());
    }

    function withdrawStake(uint256 amount, uint256 stake_index) public {
        uint256 amount_to_mint = _withdrawStake(
            amount * 10**decimals(),
            stake_index
        );
        _mint(msg.sender, amount_to_mint);
    }
}