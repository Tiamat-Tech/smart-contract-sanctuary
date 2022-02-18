// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../utils/AuthorizableUpgradeable.sol";

contract JoyToken is ERC20Upgradeable, AuthorizableUpgradeable {
    using SafeMathUpgradeable for uint256;

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public virtual initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        _mint(_msgSender(), initialSupply);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner.
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}