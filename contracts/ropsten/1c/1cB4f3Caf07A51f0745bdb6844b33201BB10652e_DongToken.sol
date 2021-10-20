// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DongToken is ERC20, ERC20Burnable, Pausable, Ownable {
    using SafeMath for uint256;

    // uint256 constant LIMIT_TOTAL_SUPPLY = 1000000000000000000000;

    constructor() ERC20("Dong Token", "DONG") {
        // _mint(msg.sender, LIMIT_TOTAL_SUPPLY);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        // require(totalSupply().add(amount)<= LIMIT_TOTAL_SUPPLY,"Cannot mint more than limit total supply");
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}