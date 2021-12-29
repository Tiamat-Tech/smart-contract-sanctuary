// ▄██▓███   ▄▄▄       ██ ▄█▀ ███▄ ▄███▓ ▄▄▄       ███▄    █
// ▓██░  ██▒▒████▄     ██▄█▒ ▓██▒▀█▀ ██▒▒████▄     ██ ▀█   █
// ▓██░ ██▓▒▒██  ▀█▄  ▓███▄░ ▓██    ▓██░▒██  ▀█▄  ▓██  ▀█ ██▒
// ▒██▄█▓▒ ▒░██▄▄▄▄██ ▓██ █▄ ▒██    ▒██ ░██▄▄▄▄██ ▓██▒  ▐▌██▒
// ▒██▒ ░  ░ ▓█   ▓██▒▒██▒ █▄▒██▒   ░██▒ ▓█   ▓██▒▒██░   ▓██░
// ▒▓▒░ ░  ░ ▒▒   ▓▒█░▒ ▒▒ ▓▒░ ▒░   ░  ░ ▒▒   ▓▒█░░ ▒░   ▒ ▒
// ░▒ ░       ▒   ▒▒ ░░ ░▒ ▒░░  ░      ░  ▒   ▒▒ ░░ ░░   ░ ▒░
// ░░         ░   ▒   ░ ░░ ░ ░      ░     ░   ▒      ░   ░ ░
// ░              ░  ░░  ░          ░         ░  ░         ░

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Token is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    //AccessControl design pattern choice made due to security
    constructor() ERC20("Token", "TOKEN") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //owner should be transfered once contract is deployed
    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not the minter");
        _mint(to, amount);
    }
}