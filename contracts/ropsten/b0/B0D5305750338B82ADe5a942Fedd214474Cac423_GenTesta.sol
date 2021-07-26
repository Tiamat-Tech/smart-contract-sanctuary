// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/[email protected]/access/OwnableUpgradeable.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20FlashMintUpgradeable.sol";
import "@openzeppelin/[email protected]/proxy/utils/Initializable.sol";

contract GenTesta is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, ERC20FlashMintUpgradeable {
    function initialize() initializer public {
        __ERC20_init("Gen Testa", "TSTA");
        __ERC20Burnable_init();
        __Ownable_init();
        __ERC20FlashMint_init();

        _mint(msg.sender, 9000999000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}