// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Token is ERC20, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 constant public ADMIN_ROLE = keccak256("Admin Role");



    constructor() ERC20("Token", "Token") {
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
    }

    modifier checkRole (bytes32 _role) {
        require(hasRole(_role, msg.sender), 'Access Denied');
        _;
    }

    function mint(address to, uint256 amount) public checkRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public checkRole(BURNER_ROLE) {
        _burn(from, amount);
    }
}