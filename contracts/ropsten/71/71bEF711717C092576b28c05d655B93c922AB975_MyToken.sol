// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract MyToken is ERC20Upgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    uint256 public manualMinted;
    uint256 public autoMinted;

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public virtual initializer {
        __ERC20_init(name, symbol);
        _mint(_msgSender(), initialSupply);
        __Ownable_init();
        manualMinted = 0;
        autoMinted = 0;
    }

    function manualMint() public {
        manualMinted = manualMinted.add(2);
    }
    function autoMint() public {
        autoMinted = autoMinted.add(3);
    }

}