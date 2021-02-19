// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "./interfaces/ILfi.sol";

contract Lfi is ERC20Capped, AccessControl, ILfi {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public immutable teamPreMinted;
    address public immutable teamAccount;

    address public governanceAccount;

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
        _setupRole(DEFAULT_ADMIN_ROLE, governanceAccount);

        teamPreMinted = teamPreMinted_;
        teamAccount = teamAccount_;

        _mint(teamAccount_, teamPreMinted_);
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "LFI: sender not authorized");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "LFI: sender not authorized");
        _;
    }

    function mint(address to, uint256 amount)
        external
        override
        onlyRole(MINTER_ROLE)
    {
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
        _setupRole(DEFAULT_ADMIN_ROLE, governanceAccount);
    }

    function addMinter(address account) external onlyBy(governanceAccount) {
        require(account != address(0), "LFI: account is the zero address");
        require(
            !hasRole(MINTER_ROLE, account),
            "LFI: account already has minter role"
        );

        grantRole(MINTER_ROLE, account);
    }

    function removeMinter(address account) external onlyBy(governanceAccount) {
        require(account != address(0), "LFI: account is the zero address");
        require(
            hasRole(MINTER_ROLE, account),
            "LFI: account doesn't have minter role"
        );

        revokeRole(MINTER_ROLE, account);
    }
}