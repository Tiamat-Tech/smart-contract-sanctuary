// contracts/ERC20Token.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BVHERC20Token is ContextUpgradeable, AccessControlUpgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

   /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
    */


  function initialize() public initializer {
    __Context_init();
    __AccessControl_init_unchained();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

    __ERC20_init_unchained("Bien VH Super Coin", "BVH");
    __ERC20Burnable_init_unchained();

    __Pausable_init_unchained();
    __ERC20Pausable_init_unchained();
  }

  function mint(address to, uint256 amount) public {
    require(hasRole(MINTER_ROLE, _msgSender()), "BVHERC20Token: must have minter role to mint");
    _mint(to, amount);
  }

  function pause() public {
    require(hasRole(PAUSER_ROLE, _msgSender()), "BVHERC20Token: must have pauser role to pause");
    _pause();
  }

  function unpause() public {
    require(hasRole(PAUSER_ROLE, _msgSender()), "BVHERC20Token: must have pauser role to unpause");
    _unpause();
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override (ERC20PausableUpgradeable, ERC20Upgradeable){
    super._beforeTokenTransfer(from, to, amount);
  }
}