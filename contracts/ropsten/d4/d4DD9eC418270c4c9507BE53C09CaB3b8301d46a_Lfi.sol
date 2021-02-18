// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "./interfaces/ILfi.sol";

contract Lfi is ERC20Capped, ILfi {
    uint256 public immutable teamPreMinted;
    address public immutable teamAccount;

    address public governanceAccount;
    address public minter;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        uint256 teamPreMinted_,
        address teamAccount_
    ) ERC20(name_, symbol_) ERC20Capped(cap_) {
        require(
            teamAccount_ != address(0),
            "LFI: team account is the zero address"
        );

        governanceAccount = msg.sender;
        teamPreMinted = teamPreMinted_;
        teamAccount = teamAccount_;

        _mint(teamAccount_, teamPreMinted_);
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "LFI: sender not authorized");
        _;
    }

    function mint(address to, uint256 amount) external override onlyBy(minter) {
        _mint(to, amount);
    }

    function setGovernanceAccount(address newGovernanceAccount)
        external
        onlyBy(governanceAccount)
    {
        require(
            newGovernanceAccount != address(0),
            "LFI: new governance account is the zero address"
        );

        governanceAccount = newGovernanceAccount;
    }

    function setMinter(address newMinter) external onlyBy(governanceAccount) {
        require(newMinter != address(0), "LFI: new minter is the zero address");

        minter = newMinter;
    }
}