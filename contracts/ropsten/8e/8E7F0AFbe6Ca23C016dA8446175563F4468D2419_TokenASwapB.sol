// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./TokenA.sol";

// import "./TokenB.sol";

contract TokenASwapB {
    string public name = "CONTRACT";

    //PPT (PPT) - 8 decimal
    address public tokenA = 0x6057590D64e85E78f33C8057f61986F9DB77cd87;
    //Uniswap V2 LP Token 2 (LP2) - 18 decimal
    address public tokenB = 0x3e6E3d4B1d1761B4B3deA19b2244A803a011cf17;

    uint256 public rate = 10;

    event TokensSwaped(
        address account,
        address token,
        uint256 amount,
        uint256 rate
    );

    constructor() {}

    function swapTokens(uint256 _amount) public {
        uint256 tokenAmount = _amount * rate;
        // Require that EthSwap has enough tokens
        require(TokenA(tokenB).balanceOf(address(this)) >= tokenAmount);
        require(TokenA(tokenA).balanceOf(msg.sender) >= _amount);

        // Transfer Token A Away from User
        TokenA(tokenA).transfer(address(this), _amount);

        // Transfer Tokens B to the user
        TokenA(tokenB).transfer(msg.sender, tokenAmount);

        emit TokensSwaped(msg.sender, address(tokenB), _amount, rate);
    }

    function revSwapTokens(uint256 _amount) public {
        uint256 tokenAmount = _amount * rate;
        // Require that EthSwap has enough tokens
        require(TokenA(tokenB).balanceOf(address(this)) >= tokenAmount);
        require(TokenA(tokenA).balanceOf(address(this)) >= _amount);

        // Transfer Token A Away from User
        TokenA(tokenA).transfer(msg.sender, _amount);
        // Transfer Tokens B to the user
        TokenA(tokenB).transfer(address(this), tokenAmount);

        emit TokensSwaped(msg.sender, address(tokenB), _amount, rate);
    }
}