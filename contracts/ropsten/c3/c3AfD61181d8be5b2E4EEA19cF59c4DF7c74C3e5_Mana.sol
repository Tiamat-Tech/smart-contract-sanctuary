// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Mana (for Adventurers)
/// @notice This contract mints Mana for Crystals
/// @custom:unaudited This contract has not been audited. Use at your own risk.
contract Mana is Context, Ownable, ERC20 {
    // a mapping from an address to whether or not it can mint / burn
    mapping(address => bool) controllers;
    IERC721Enumerable public crystalsContract;

    constructor() Ownable() ERC20("Adventure Mana", "AMNA") {
        _mint(_msgSender(), 100000);
    }

    // function testMint(uint256 amount) external {
    //     _mint(_msgSender(), amount);
    // }

    /// @notice function for Crystals contract to mint on behalf of to
    /// @param recipient address to send mana to
    /// @param amount number of mana to mint
    function ccMintTo(address recipient, uint256 amount) external {
        // Check that the msgSender is from Crystals
        require(controllers[msg.sender], "Only controllers can mint");

        _mint(recipient, amount);
    }

    function burn(address from, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can burn");
        _burn(from, amount);
    }

    /**
    * enables an address to mint / burn
    * @param controller the address to enable
    */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    /**
    * disables an address from minting / burning
    * @param controller the address to disbale
    */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}