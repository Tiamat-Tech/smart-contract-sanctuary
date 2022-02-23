// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICash.sol";

contract CASH is ICASH, ERC20, Ownable {

  // a mapping from an address to whether or not it can mint / burn
  /* solhint-disable-next-line state-visibility */
  mapping(address => bool) controllers;

  /* solhint-disable-next-line no-empty-blocks */
  constructor() ERC20("CASH", "CASH") { }

  /**
   * mints $CASH to a recipient
   * @param to the recipient of the $CASH
   * @param amount the amount of $CASH to mint
   */
  function mint(address to, uint256 amount) external override {
    require(controllers[msg.sender], "Only controllers can mint");
    _mint(to, amount);
  }

  /**
   * burns $CASH from a holder
   * @param from the holder of the $CASH
   * @param amount the amount of $CASH to burn
   */
  function burn(address from, uint256 amount) external override {
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
}