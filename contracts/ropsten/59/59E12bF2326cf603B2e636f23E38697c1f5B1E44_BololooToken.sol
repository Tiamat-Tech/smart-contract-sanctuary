// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BololooToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public SECRET = ""; // TODO: Check is this ok?


    constructor(address minter, string memory secret) ERC20("BololooToken", "BOL") {
        SECRET = secret;
        _setupRole(MINTER_ROLE, minter);
    }

    function get_secret() public view returns(string memory) {
        return SECRET;
    } 

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, amount);
    }
}