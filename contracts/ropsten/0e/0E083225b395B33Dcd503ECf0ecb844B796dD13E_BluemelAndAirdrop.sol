pragma solidity ^0.6.0;

import "BluemelToken.sol";

contract BluemelAndAirdrop {

    BluemelToken public token;
    mapping(address => bool) alreadyReceived;

    constructor(
        address _tokenAddr
    ) public {
        token = BluemelToken(_tokenAddr);
    }

    function getAirdrop() public {
        require(!alreadyReceived[msg.sender]);
        alreadyReceived[msg.sender] = true;
        token.transfer(msg.sender, 100000000000000000000); //18 decimals token
    }
}