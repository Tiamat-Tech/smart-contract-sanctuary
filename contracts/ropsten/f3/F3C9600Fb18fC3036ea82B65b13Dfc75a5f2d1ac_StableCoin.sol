// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Stablecoin contract with the role management for coin issuance
/// @author The Systango Team

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./BlackList.sol";
import "./IStableCoin.sol";

contract StableCoin is ERC20, Pausable, Ownable, AccessControl, ReentrancyGuard, BlackList, IStableCoin
{
    // Zero Address
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    // Initialized variable
    bool private initialized;

    // The encrypted role name for CUSTODIAL ROLE
    bytes32 public constant CUSTODIAL_ROLE = keccak256("CUSTODIAL_ROLE");

    // The encrypted role name for AUDITOR ROLE
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    // The address of the assigned auditor address
    address private _auditor;

    // The address of the assigned custodial address
    address private _custodial;

    // This is the constructor of the contract. It is called at deploy time.
    
    /// @param tokenName The token name 
    /// @param tokenSymbol The token symbol
    /// @param custodialAddress The address assigned the custodial feature
    /// @param auditorAddress The address assigned the auditor feature

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        address custodialAddress,
        address auditorAddress
    ) 
    ERC20(tokenName, tokenSymbol)
    {
        require(!initialized, "Contract instance has already been initialized");
        _grantRole(CUSTODIAL_ROLE, custodialAddress);
        _grantRole(AUDITOR_ROLE, auditorAddress);
        _custodial = custodialAddress;
        _auditor = auditorAddress;
        initialized = true;
        emit Constructed(
            tokenName,
            tokenSymbol,
            custodialAddress,
            auditorAddress
        );
    }

    // This function would add an address to the blacklist mapping

    /// @param _user The account to be added to blacklist

    function addToBlackList(address _user) public override(IStableCoin) onlyOwner returns (bool) {
        require(
            _user != ZERO_ADDRESS,
            "account is the zero address"
        );
        _addToBlackList(_user);
        return true;
    }

    // This function would remove an address from the blacklist mapping

    /// @param _user The account to be removed from blacklist

    function removeFromBlackList(address _user) public override(IStableCoin) onlyOwner returns (bool) {
        require(
            _user != ZERO_ADDRESS,
            "account is the zero address"
        );
        _removeFromBlackList(_user);
        return true;
    }

    // This function would replace the new custodial address from the old
    // custodial address and revoke and grant role to them respectively
    // Only the owner can call this function
    // Cannot set the newCustodial to a blacklisted address
    
    /// @param newCustodial The new address of the custodial

    function replaceCustodial(address newCustodial)
        public
        override(IStableCoin)
        onlyOwner
        whenNotBlackListedUser(newCustodial)
    {
        require(
            newCustodial != ZERO_ADDRESS,
            "newCustodial is the zero address"
        );
        require(
            newCustodial != _custodial,
            "New Custodial cannot be same as old Custodial"
        );
        _revokeRole(CUSTODIAL_ROLE, _custodial);
        _custodial = newCustodial;
        _grantRole(CUSTODIAL_ROLE, newCustodial);
        emit ChangeCustodial(newCustodial);
    }

    // This function would replace the new custodial address from the old
    // custodial address and revoke and grant role to them respectively
    // Only the owner can call this function
    // Cannot set the newCustodial to a blacklisted address

    /// @param newAuditor The new address of the custodial

    function replaceAuditor(address newAuditor)
        public
        override(IStableCoin)
        onlyOwner
        whenNotBlackListedUser(newAuditor)
    {
        require(
            newAuditor != ZERO_ADDRESS,
            "newAuditor is the zero address"
        );
        require(
            newAuditor != _auditor,
            "New Auditor cannot be same as old Auditor"
        );
        _revokeRole(AUDITOR_ROLE, _auditor);
        _auditor = newAuditor;
        _grantRole(AUDITOR_ROLE, newAuditor);
        emit ChangeAuditor(newAuditor);
    }

    // This function would pause the stablecoin contract
    // Only the owner can call this function

    function pause() public override(IStableCoin) onlyOwner {
        _pause();
    }

    // This function would unpause the stablecoin contract
    // Only the owner can call this function

    function unpause() public override(IStableCoin) onlyOwner {
        _unpause();
    }

    // This function would wipe the amount from the account which are provided
    // Only the auditor can call this function

    /// @param account The account from which the tokens would be wiped
    /// @param amount The token amount which would be wiped
    
    function wipe(address account, uint256 amount) public override(IStableCoin) nonReentrant onlyRole(AUDITOR_ROLE) {
        require(
            account != ZERO_ADDRESS,
            "account is the zero address"
        );
        require(
            amount > 0,
            "Amount should be greater than 0"
        );
        uint256 balance = balanceOf(account);
        require(
            amount <= balance,
            "Wipe amount is greater than user token balance"
        );
        super._transfer(account, _auditor, amount);
        _burn(_auditor, amount);
        emit Wipe(account, amount);
    }

    // This function would mint the tokens to the account which are provided
    // Only the custodial can call this function
    // Cannot mint to a blacklisted address

    /// @param account The account where the tokens would be minted
    /// @param amount The token amount which would be minted

    function mint(address account, uint256 amount) public override(IStableCoin) nonReentrant onlyRole(CUSTODIAL_ROLE) whenNotBlackListedUser(account) {
        require(
            account != ZERO_ADDRESS,
            "account is the zero address"
        );
        require(
            amount > 0,
            "Amount should be greater than 0"
        );
        _mint(account, amount);
        emit Mint(account, amount);
    }

    // This function would burn the tokens from the account which are provided
    // Only the custodial can call this function

    /// @param account The account where the tokens would be burned
    /// @param amount The token amount which would be burned

    function burn(address account, uint256 amount) public override(IStableCoin) nonReentrant onlyRole(CUSTODIAL_ROLE) {
        require(
            account != ZERO_ADDRESS,
            "account is the zero address"
        );
        require(
            amount > 0,
            "Amount should be greater than 0"
        );
        _burn(account, amount);
        emit Burn(account, amount);
    }

    // This function would transfer the tokens to the account which are provided
    // Cannot send tokens to a blacklisted address

    /// @param to The account to which the tokens would be transferred
    /// @param amount The token amount which would be transferred

    function transfer(address to, uint256 amount) public override(ERC20) whenNotBlackListedUser(to) returns (bool) {
        super._transfer(_msgSender(), to, amount);
        return true;
    }

    // This function would transfer the tokens from an account to another
    // account which are provided
    // Cannot send tokens to a blacklisted address

    /// @param from The account from which the tokens would be transferred
    /// @param to The account to which the tokens would be transferred
    /// @param amount The token amount which would be transferred

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20) whenNotBlackListedUser(to) returns (bool) {
        super.transferFrom(from, to, amount);
        return true;
    }
}