/**
 *Submitted for verification at Etherscan.io on 2021-08-03
*/

pragma solidity ^0.4.21;

contract Forward {
    address public receiver;

    // Constructor, pass the address of the account you want this contract
    // to forward any incoming ether to.
    function Forward(address _receiver) public {
        receiver = _receiver;
    }

    function() public payable {
        // Forward the received ether to receiver, as well as some gas,
        // which the receiver can use to run code
        // If something goes wrong, the ether is sent back
        require(receiver.call.gas(gasleft() - 2000).value(msg.value)());
    }
}