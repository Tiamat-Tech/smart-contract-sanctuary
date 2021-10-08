// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "solowei/contracts/TwoStageOwnable.sol";

contract TGT is ERC20Capped, TwoStageOwnable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        address owner_,
        address recipient_,
        uint256 amount_
    ) public ERC20(name_, symbol_) ERC20Capped(cap_) TwoStageOwnable(owner_) {
        _mint(recipient_, amount_);
    }

    function mint(address account_, uint256 amount_) external onlyOwner returns (bool) {
        _mint(account_, amount_);
        return true;
    }
}