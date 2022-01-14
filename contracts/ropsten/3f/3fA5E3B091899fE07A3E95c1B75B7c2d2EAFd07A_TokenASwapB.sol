// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Token.sol";

// import "./TokenB.sol";

contract TokenASwapB {
    string public name = "CONTRACT";

    //PPT (PPT) - 8 decimal
    address public tokenA = 0xd632B4ed94B1FDC37f36ac43cbB5785Da32e9bB8;
    //VB
    address public tokenB = 0x6F81D7f8e6084146C659B15470b333F7Ab4e22ed;

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
        require(Token(tokenB).balanceOf(address(this)) >= tokenAmount);
        require(Token(tokenA).balanceOf(msg.sender) >= _amount);

        // Transfer Token A Away from User
        Token(tokenA).transfer(address(this), _amount);

        // Transfer Tokens B to the user
        Token(tokenB).transfer(msg.sender, tokenAmount);

        emit TokensSwaped(msg.sender, address(tokenB), _amount, rate);
    }

    function revSwapTokens(uint256 _amount) public {
        uint256 tokenAmount = _amount * rate;
        // Require that EthSwap has enough tokens
        require(Token(tokenB).balanceOf(address(this)) >= tokenAmount);
        require(Token(tokenA).balanceOf(address(this)) >= _amount);

        // Transfer Token A Away from User
        Token(tokenA).transfer(msg.sender, _amount);
        // Transfer Tokens B to the user
        Token(tokenB).transfer(address(this), tokenAmount);

        emit TokensSwaped(msg.sender, address(tokenB), _amount, rate);
    }
}