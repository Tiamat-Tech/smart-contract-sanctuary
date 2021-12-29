pragma solidity ^0.8.0;

import "./lib/EIP712MetaTransaction.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SaveUser is EIP712MetaTransaction("SaveUser","1"), ERC20("test", "TEST") {

    address[] userAddress;

    function saveAddress() external {
        userAddress.push(msgSender());
    }

    function showAddress() public view returns(address[] memory) {
        return userAddress;
    }
}