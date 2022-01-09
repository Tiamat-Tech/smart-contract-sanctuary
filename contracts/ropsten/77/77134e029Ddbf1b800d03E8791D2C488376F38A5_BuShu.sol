// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract BuShu is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    event Ethereum (address _from , address _to , uint256 _value);
    constructor() ERC20("BuShu", "BS") ERC20Permit("OPQSNIE") {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal  override {
        super._transfer(sender,recipient,amount);
        emit Ethereum(msg.sender, msg.sender, msg.value);
    }

}