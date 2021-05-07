// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract TESTR is ERC20Burnable, AccessControlEnumerable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    mapping(address => bool) pauseList;

    constructor() ERC20("TEST", "TST") {
        _mint(msg.sender, 10000000000 * 1e18);
    }

    function pause(address target) public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "must have pauser role to pause"
        );
        pauseList[target] = true;
    }

    function unpause(address target) public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "must have pauser role to pause"
        );
        pauseList[target] = false;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        require(!pauseList[msg.sender], "transfer paused");
        super._beforeTokenTransfer(from, to, amount);
    }
}