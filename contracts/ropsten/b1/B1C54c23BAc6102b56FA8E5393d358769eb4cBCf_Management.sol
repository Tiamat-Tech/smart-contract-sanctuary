// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./access/AccessControl.sol";
import "./access/IAccessControl.sol";

/**
 * @title Management contract
 */
contract Management is AccessControl {
    receive() external payable {}
    fallback() external payable {}

    uint256 _fee;
    uint256 _percent;

    constructor() {
        _setupRole(ADMIN_KEY, msg.sender);
        _setupRole(SYSTEM_KEY, msg.sender);
        _fee = 0.001 ether;
        _percent = 100;
    }

    function setFee(uint256 _setFee) public onlyRole(SYSTEM_KEY) {
        _fee = _setFee;
    }

    function setPercent(uint256 _setPercent) public onlyRole(SYSTEM_KEY) {
        _percent = _setPercent;
    }

    function fee() public view returns (uint256) {
        return _fee;
    }

    function percent() public view returns (uint256) {
        return _percent;
    }
}