// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "./Owned.sol";

contract BaseStorage is Owned {
    address public controllerAddr;

    modifier onlyController() {
        require(msg.sender == controllerAddr);
        _;
    }

    function setControllerAddr(address _controllerAddr) public onlyOwner {
        controllerAddr = _controllerAddr;
    }
}