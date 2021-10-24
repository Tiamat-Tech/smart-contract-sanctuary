// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "openzeppelin-solidity/contracts/utils/Context.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";


contract CropBytes is Ownable, ERC20Pausable {
  // IEO	Swap 	Foundation	Product 	Marketing	Team 	Advisor	Mining
    
  /**
   * @dev Constructor that gives msg.sender all of existing tokens.
   */
  constructor ()  ERC20("CropBytes", "CBX") {
    _mint(msg.sender, 500000000 * (10 ** uint256(decimals())));
  }
  function pause() public virtual  onlyOwner {
       
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual onlyOwner {
        _unpause();
    }

}