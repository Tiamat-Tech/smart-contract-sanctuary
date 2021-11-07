// contracts/Box.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import Auth from the access-control subdirectory
import "./access-control/Auth.sol";

contract Box {
    string private _value;
    Auth private _auth;

    event ValueChanged(string value);

    constructor() {
        _auth = new Auth(msg.sender);
    }

    function store(string memory value) public {
        // Require that the caller is registered as an administrator in Auth
        require(_auth.isAdministrator(msg.sender), "Unauthorized");

        _value = value;
        emit ValueChanged(value);
    }

    function retrieve() public view returns (string memory) {
        return _value;
    }
}