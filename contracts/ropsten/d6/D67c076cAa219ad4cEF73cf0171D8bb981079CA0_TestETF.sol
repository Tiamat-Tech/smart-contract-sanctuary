//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.5;

import "./ISwap.sol";
import "./OwnableTimeMintCoin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TestETF is ERC20, OwnableTimeMintCoin, ISwap {

    constructor() OwnableTimeMintCoin("TestETF", "TETF", 1000 * 10 ** uint(decimals()), 5 minutes) {
        _setMintToAddress(address(this));
        return;
    }

    function swapEthForToken(uint256 ethIn, address tokenOut) public onlyOwner() returns(uint256 amountOut) {
        return swap(0xc778417E063141139Fce010982780140Aa0cD5Ab, tokenOut, ethIn);
    }

    function recieve() public payable {
        return;
    }
}