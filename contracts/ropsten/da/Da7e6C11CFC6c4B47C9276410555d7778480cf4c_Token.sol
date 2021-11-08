// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./TokenERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 decimal = 10**18;

    constructor(uint256 total) ERC20("Token", "TK") {
        mint(total);
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return (super.balanceOf(account) / decimal);
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount * decimal);
        return true;
    }

    function mint(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount * decimal);
    }

    function approveTransfer(address tokenERC721, uint256 value) public onlyOwner {
        require(value >= 1);
        require(balanceOf(msg.sender) >= value * 100);
        uint256 temp = value * 100 * decimal;
        approve(address(tokenERC721), temp);
        //tokenERC721.mint(address(this), temp);
    }
}