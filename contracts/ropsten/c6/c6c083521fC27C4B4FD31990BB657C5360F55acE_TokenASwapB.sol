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

    uint256 public rateConversion = 1e9;

    event TokensSwaped(
        address account,
        address token,
        uint256 amount,
        uint256 rate
    );

    event Data(uint256 data, bytes32 text);

    constructor() {}

    function swapToken(uint256 _amount) public {
        uint256 AmountTokenB = _amount * rateConversion;

        emit Data(AmountTokenB, "AmountTokenB");
        emit Data(_amount, "Amount parameter");

        // Require that EthSwap has enough tokens
        require(
            Token(tokenB).balanceOf(address(this)) >= AmountTokenB,
            "User doesn't have enough TokenB"
        );
        require(
            Token(tokenA).balanceOf(msg.sender) >= _amount,
            "User doesn't have enough TokenA"
        );
        require(
            Token(tokenA).allowance(msg.sender, address(this)) >= AmountTokenB,
            "Increase PPT Allowance for Swap contract"
        );

        // Transfer Token A Away from User
        Token(tokenA).transfer(address(this), _amount);
        // Transfer Tokens B to the user
        Token(tokenB).transfer(msg.sender, AmountTokenB);

        emit TokensSwaped(msg.sender, address(tokenB), _amount, AmountTokenB);
    }
}