// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract NAFFToken is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, Pausable {
    uint256 public initialSupply = 10000 * 10**decimals();
    uint256 public claimSupply = 2500 * 10**decimals();

    constructor(address distributor) ERC20("Naffiti Token", "NAFF") {
        _mint(address(this), initialSupply);
        _transfer(address(this), distributor, claimSupply);
        _transfer(address(this), msg.sender, initialSupply - claimSupply);
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}