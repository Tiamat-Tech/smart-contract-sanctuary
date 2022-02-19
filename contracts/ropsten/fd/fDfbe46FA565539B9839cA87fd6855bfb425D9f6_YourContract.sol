pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YourContract is Ownable, ERC20 {
    address tokenAdd = 0x72F80717BDF3c1B1288Dee4611c30c3d73b3dC9E;
    ERC20 public token;

    //address public owner;

    constructor() ERC20("", "") {
        //owner = msg.sender;
        // what should we do on deploy?
    }

    struct LockedAccount {
        uint256 amountETH;
        uint256 amountTokens;
        uint256 date;
    }

    mapping(address => LockedAccount) lockedAccounts;

    // function approveToken(address _to, uint256 _amount) public {
    //     token = ERC20(tokenAdd);
    //     token.approve(_to, _amount);
    // }

    function lockMoney(uint256 _amountTokens) public payable {
        token = ERC20(tokenAdd);
        token.approve(address(this), _amountTokens);
        token.transferFrom(msg.sender, address(this), _amountTokens);
        LockedAccount memory _lockedAccounts = LockedAccount({
            amountETH: msg.value,
            amountTokens: _amountTokens,
            date: block.timestamp
        });

        lockedAccounts[msg.sender] = _lockedAccounts;
    }

    // to support receiving ETH by default
    receive() external payable {}

    fallback() external payable {}
}