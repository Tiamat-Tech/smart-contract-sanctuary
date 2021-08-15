// SPDX-License-Identifier: MIT

/* $URUS is the governance token of the ERC20 Ecosystem
    t.me/UrusGovernance
    ♉  1 of 7
*/
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract URUS is ERC20, Pausable, Ownable {
    constructor() ERC20("Urus - t.me/UrusGovernance", "URUS") {
        _mint(msg.sender, 1000000000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}