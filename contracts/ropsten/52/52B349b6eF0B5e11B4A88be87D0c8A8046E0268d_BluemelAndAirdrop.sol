pragma solidity ^0.6.0;

import "BluemelToken.sol";

contract BluemelAndAirdrop {

    BluemelToken public token;
    constructor(
        address _tokenAddr
    ) public {
        token = BluemelToken(_tokenAddr);
    }

    function getAirdrop() public {
        token.transfer(msg.sender, 100000000000000000000); //18 decimals token
    }


}