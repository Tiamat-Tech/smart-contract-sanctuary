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

    uint256 public rateConversion = 9;

    event TokensSwaped(
        address account,
        address token,
        uint256 amount,
        uint256 rate
    );

    constructor() {}

    function swapToken(uint256 _amount) public {
        uint256 AmountTokenB = _amount ** rateConversion;
        // Require that EthSwap has enough tokens
        require(Token(tokenB).balanceOf(address(this)) >= AmountTokenB);
        require(Token(tokenA).balanceOf(msg.sender) >= _amount);

        // Transfer Token A Away from User
        Token(tokenA).transfer(address(this), _amount);

        // Transfer Tokens B to the user
        Token(tokenB).transfer(msg.sender, AmountTokenB);

        emit TokensSwaped(msg.sender, address(tokenB), _amount, AmountTokenB);
    }
}