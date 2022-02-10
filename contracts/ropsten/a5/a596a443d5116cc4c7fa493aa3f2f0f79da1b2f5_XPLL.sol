// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import "../token/ERC20/ERC20Mintable.sol";
import "./ERC20.sol";
import "./extensions/ERC20Pausable.sol";
import "./extensions/ERC20Burnable.sol";
import "./extensions/Ownable.sol";


/**
 * @title XPLL
 */
contract XPLL is ERC20Pausable, ERC20Burnable, Ownable  {
    
    constructor (string memory tokenName, string memory tokenSymbol, uint initialSupply) ERC20(tokenName, tokenSymbol) {

        uint256 tokenAmount = initialSupply * (10 ** uint256(decimals()));
        _mint(_msgSender(), tokenAmount);

    }

    function mint(address account, uint256 amount) onlyOwner public {
        _mint(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
}