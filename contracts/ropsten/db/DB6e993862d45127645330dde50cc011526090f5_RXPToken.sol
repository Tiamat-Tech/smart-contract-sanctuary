// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract RXPToken is Initializable,OwnableUpgradeable,ERC20Upgradeable{
    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     */

    function initialize(string memory name, string memory symbol) public {
        __Ownable_init();
        __ERC20_init_unchained(name, symbol);     
        _mint(owner(),500000000 * 10 ** 8 );
    } 
}