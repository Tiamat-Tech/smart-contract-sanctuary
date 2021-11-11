pragma solidity ^0.6.0;

import "Bluemel.sol";

contract BluemelAirdrop {

    Bluemel public token;
    mapping(address => bool) public alreadyReceived;

    constructor(
        address _tokenAddr
    ) public {
        token = Bluemel(_tokenAddr);
    }

    function getAirdrop() public {
        require(!alreadyReceived[msg.sender], "FEHLER FEHLER");
        alreadyReceived[msg.sender] = true;
        token.transfer(msg.sender, 100000000000000000000); //18 decimals token
    }
    function hasAlreadyAirdrop() public returns(bool) {
        if(alreadyReceived[msg.sender]) {
            return true;
        } else {
            return false;
        }
    }
}