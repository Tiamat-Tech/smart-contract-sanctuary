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

    mapping(address => uint256) private _mintAllowances;

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
     * @param to Wallet address token to be minted to
     * @param amount Amount of tokens
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        uint256 currentMintAllowance = _mintAllowances[_msgSender()];
        require(
            currentMintAllowance >= amount,
            "ERC20: mint amount exceeds mint allowance"
        );
        unchecked {
            _approveMintAllowance(_msgSender(), currentMintAllowance - amount);
        }
        _mint(to, amount);
    }

    /**
     * @notice Only address with BURNER_ROLE mints tokens
     * @param from Wallet address token to be burned from
     * @param amount Amount of tokens
     */
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        uint256 currentMintAllowance = _mintAllowances[_msgSender()];
        unchecked {
            _approveMintAllowance(_msgSender(), currentMintAllowance + amount);
        }
        _burn(from, amount);
    }

    /**
     * @notice Set amount as mintAllowance of minter
     * @param minter Wallet address of the minter (Requires Role - MINTER_ROLE)
     * @param amount Amount of tokens
     */
    function _approveMintAllowance(address minter, uint256 amount) internal {
        require(minter != address(0), "ERC20: approve to the zero address");
        _mintAllowances[minter] = amount;
    }

    /**
     * @notice Increase the mint allowance for the minter, Requires DEFAULT_ADMIN_ROLE.
     * @param minter Wallet address of the minter
     * @param amount Amount of tokens
     */
    function increaseMintAllowance(address minter, uint256 amount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        _approveMintAllowance(minter, _mintAllowances[minter] + amount);
        return true;
    }

    /**
     * @notice Decrease the mint allowance for the minter, Requires DEFAULT_ADMIN_ROLE.
     * @param minter Wallet address of the minter
     * @param subtractedValue Amount of tokens
     */
    function decreaseMintAllowance(address minter, uint256 subtractedValue)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        uint256 currentMintAllowance = _mintAllowances[minter];
        require(
            currentMintAllowance >= subtractedValue,
            "ERC20: decreased mint allowance below zero"
        );
        _approveMintAllowance(minter, currentMintAllowance - subtractedValue);
        return true;
    }

    /**
     * @notice Returns the current mint allowance..
     * @param minter Wallet address of the minter
     * @return uint256 - mint allowance
     */
    function mintAllowance(address minter) public view returns (uint256) {
        return _mintAllowances[minter];
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
        super._beforeTokenTransfer(from, to, amount);
    }

}