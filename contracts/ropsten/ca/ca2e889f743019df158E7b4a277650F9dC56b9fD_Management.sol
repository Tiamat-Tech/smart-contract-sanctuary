// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Management/AccessControl.sol";
import "./Management/IAccessControl.sol";

/**
 * @title Management contract
 */
contract Management is AccessControl {
    receive() external payable {}
    fallback() external payable {}

    event Withdrawal (address caller, address receiver, uint256 amount);

    constructor() {
        _setupRole(ADMIN_KEY, msg.sender);
        _setupRole(SYSTEM_KEY, msg.sender);
    }

    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw(address receiver) public onlyRole(SYSTEM_KEY) {
        uint256 _balance = address(this).balance;
        (bool success, ) = payable(receiver).call{value: address(this).balance}("");
        require(success, "Management: ether transfer failed");

        emit Withdrawal (msg.sender, receiver, _balance);
    }
}