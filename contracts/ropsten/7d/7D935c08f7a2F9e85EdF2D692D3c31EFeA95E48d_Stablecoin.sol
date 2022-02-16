// contracts/Stablecoin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Stablecoin smart contract
 */
contract Stablecoin is ERC20, AccessControl, Pausable {
    // keccak hash for roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    //mapping for blacklist address
    mapping(address => bool) public isBlackListed;

    // Sets contract creator as default admin role
    constructor() ERC20("USD Stablecoin", "USDS") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Changes decimal from 18 to 6
     * @return fixed decimal value
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /**
     * @notice Only address with MINTER_ROLE mints tokens
     * @param amount Amount of tokens
     */
    function mint(address user, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(user, amount);
    }

    /**
     * @notice Only address with BURNER_ROLE mints tokens
     * @param amount Amount of tokens
     */
    function burn(address user, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(user, amount);
    }

    /// @notice Pauses the contract.
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice UnPause the contract.
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!isBlackListed[msg.sender], "User is blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }

    /// @notice Add user to blacklist.
    function addBlacklist(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        isBlackListed[user] = true;
        emit AddedBlacklistUser(user);
    }

    /// @notice Remove user from blacklist.
    function removeBlacklist(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        isBlackListed[user] = false;
        emit removedBlacklistUser(user);
    }

    event AddedBlacklistUser(address _user);
    event removedBlacklistUser(address _user);
}