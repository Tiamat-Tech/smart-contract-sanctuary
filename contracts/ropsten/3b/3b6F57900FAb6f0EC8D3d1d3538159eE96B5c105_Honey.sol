// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.7.3;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Honey is ERC20, Ownable {

  // a mapping from an address to whether or not it can mint / burn
  mapping(address => bool) controllers;

  uint256 public constant GIVEAWAY_MAX = 6000000 ether;

  uint256 public giveawayMinted;
  
  constructor() ERC20("HONEY", "HONEY") { }

  /**
   * mints $HONEY to a recipient
   * @param to the recipient of the $HONEY
   * @param amount the amount of $HONEY to mint
   */
  function mint(address to, uint256 amount) external {
    require(controllers[msg.sender], "Only controllers can mint");
    _mint(to, amount);
  }

  function mintGiveaway(address[] calldata addresses, uint256 amount) external onlyOwner {
      for (uint256 i = 0; i < addresses.length; i++) {
          require(addresses[i] != address(0), "Cannot send to null address");
          require(giveawayMinted + amount <= GIVEAWAY_MAX, "All tokens on-sale already sold");
          _mint(addresses[i], amount);
          giveawayMinted += amount;
      }
  }

  /**
   * burns $HONEY from a holder
   * @param from the holder of the $HONEY
   * @param amount the amount of $HONEY to burn
   */
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
}