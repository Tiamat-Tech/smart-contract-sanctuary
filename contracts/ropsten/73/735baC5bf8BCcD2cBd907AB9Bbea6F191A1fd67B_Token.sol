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

    TokenERC721 tokenERC721;
    uint256 decimal = 10**18;

    constructor(uint256 total, address tokenNFT) ERC20("Token", "TK") {
        tokenERC721 = TokenERC721(tokenNFT);
        mint(total);
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
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

    function burn(uint256 value) public onlyOwner {
        require(value >= 100);
        require(balanceOf(msg.sender) >= value);
        uint256 temp = (value / 100) * 100 * decimal;
        approve(address(tokenERC721), temp);
        tokenERC721.mint(address(this), temp);
    }

    function getBalancesNFT() public view returns (uint256) {
        return tokenERC721.getBalances(msg.sender);
    }
}