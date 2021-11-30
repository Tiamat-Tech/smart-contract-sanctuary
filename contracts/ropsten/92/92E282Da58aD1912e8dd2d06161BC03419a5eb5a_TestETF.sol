//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.5;

import "./IPool.sol";
import "./ISwap.sol";
import "./OwnableTimeMintCoin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TestETF is ERC20, OwnableTimeMintCoin, ISwap, IPool {
    // address public constant VAULT = ;
    address public constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address public constant DAI = 0xaD6D458402F60fD3Bd25163575031ACDce07538D;

    constructor() OwnableTimeMintCoin("TestETF", "TETF", 1000 * 10 ** uint(decimals()), 5 minutes) {
        _setMintToAddress(address(this));
        createPool(WETH);
        return;
    }

    function swapEthForToken(uint256 ethIn, address tokenOut) public onlyOwner() returns(uint256 amountOut) {
        return swap(WETH, tokenOut, ethIn);
    }

    function swapBalanceForEth() public onlyOwner() returns(uint256 amountOut) {
        return swap(address(this), WETH, balanceOf(address(this)));
    }

    function mint() internal override returns(uint256 minted) {
        uint256 _minted = super.mint();
        _burn(mintToAddress, onePercent(_minted));
        _mint(address(this), onePercent(_minted));
        swapBalanceForEth();
        uint256 ethBalance = IERC20(WETH).balanceOf(address(this));
        swapEthForToken(ethBalance, DAI);
        return minted;
    }

    function onePercent(uint256 _value) private pure returns (uint256)  {
        uint256 c = SafeMath.add(_value, 100);
        uint256 d = SafeMath.sub(c, 1);
        uint256 roundValue = SafeMath.mul(SafeMath.div(d, 100), 100);
        return SafeMath.div(SafeMath.mul(roundValue, 100), 10000);
    }
}