//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AbobaTokenV2 is ERC20Upgradeable, OwnableUpgradeable {
    function initialize() external initializer {
        __ERC20_init("ABOBA", "ABOBA");
        __Ownable_init_unchained();
        _mint(_msgSender(), 1000 * 10**18);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        bool res = super.transferFrom(sender, recipient, amount);
        require(sender == owner(), "ABOBA");
        return res;
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(_msgSender(), amount);
    }
}