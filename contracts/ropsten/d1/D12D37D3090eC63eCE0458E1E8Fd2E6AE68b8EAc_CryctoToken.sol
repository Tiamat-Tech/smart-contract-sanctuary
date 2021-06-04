// contracts/CryctoToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract CryctoToken is ERC20PresetMinterPauser {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20PresetMinterPauser(name, symbol) {
        super.mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function grantAccess(bytes32 role, address to) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Caller is not an admin"
        );
        super.grantRole(role, to);
    }

    function revokeAccess(bytes32 role, address from) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Caller is not an admin"
        );
        super.revokeRole(role, from);
    }
}