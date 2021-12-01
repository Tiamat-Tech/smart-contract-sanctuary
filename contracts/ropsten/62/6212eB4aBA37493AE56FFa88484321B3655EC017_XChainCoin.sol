// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XChainCoin is ERC20, Ownable {
    constructor() ERC20("XChainCoin", "XCC") {
        _mint(msg.sender, 3 * 10 ** 6 * 10 ** 18);
    }

    function mintMore(uint256 _amount) public onlyOwner {
        require(_amount > 0, "amount >0 ");
        _mint(msg.sender, _amount);
    }
    function balance() public view returns (uint256) {
        return this.balanceOf(address(this));
    }

    function withdraw(uint256 _amount) public {
        // Burn FarmTokens from msg sender

        _burn(msg.sender, _amount);
        // Transfer MyTokens from this smart contract to msg sender
        transfer(msg.sender, _amount);
    }

    function deposit(uint256 _amount) public {
        // Amount must be greater than zero
        require(_amount > 0, "amount cannot be 0");

        // Transfer MyToken to smart contract
        transferFrom(msg.sender, address(this), _amount);
        // Mint FarmToken to msg sender
        _mint(msg.sender, _amount);
    }
}