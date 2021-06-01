// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @notice A mintable ERC20
 */
contract MeowToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public description = "This is an amazing description.";

    event UpdatedDescription(string oldDescription, string newDescription);

    constructor() public ERC20("MEOW Token", "MEOWMEOWMEOW") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);        
    }

    function mint(address to, uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Only minter can mint");
        _mint(to, amount);
    }

    function updateDescriptions(string memory newDescription) public {
        string memory oldDescription = description;
        description = newDescription;
        emit UpdatedDescription(oldDescription, newDescription);
    }
}