// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact [email protected]
contract P202 is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    uint256 public constant cliffPeriod = 180 * 24 * 60 * 60;
    uint256 public constant lockPeriod = 365 * 24 * 60 * 60;
    mapping(address => bool) public isLocked;
    mapping(address => uint256) public locked;
    mapping(address => uint256) public lockedAt;

    constructor() ERC20("Project 202", "P202") ERC20Permit("Project 202") {
        _mint(msg.sender, 500000000 * 10**decimals());
    }

    function multiTransfer(address[] memory recipients, uint256[] memory values)
        public
    {
        require(
            recipients.length == values.length,
            "ERC20: multiTransfer mismatch"
        );
        for (uint256 i = 0; i < recipients.length; i++) {
            transfer(recipients[i], values[i]);
        }
    }

    function airdrop(address[] memory recipients, uint256[] memory values)
        public
        onlyOwner
    {
        require(recipients.length == values.length, "ERC20: airdrop mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            if (!isLocked[recipients[i]]) {
                isLocked[recipients[i]] = true;
                lockedAt[recipients[i]] = block.timestamp;
            }
            locked[recipients[i]] += values[i];
            transfer(recipients[i], values[i]);
        }
    }

    function lockedOf(address account) public view returns (uint256) {
        if ((block.timestamp - lockedAt[account]) >= (cliffPeriod + lockPeriod))
            return 0;

        if ((block.timestamp - lockedAt[account]) <= cliffPeriod)
            return locked[account];

        return
            locked[account] -
            (locked[account] *
                (block.timestamp - cliffPeriod - lockedAt[account])) /
            lockPeriod;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (isLocked[from]) {
            uint256 lockedAmount = lockedOf(from);
            if (lockedAmount == 0) {
                isLocked[from] = false;
                locked[from] = 0;
                lockedAt[from] = 0;
            } else {
                require(
                    (balanceOf(from) - amount) >= lockedAmount,
                    "ERC20: transfer amount exceeds locked amount"
                );
            }
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}