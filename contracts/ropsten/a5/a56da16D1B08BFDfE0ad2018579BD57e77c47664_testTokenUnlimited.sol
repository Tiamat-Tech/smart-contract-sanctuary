// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract testTokenUnlimited is ERC20, Ownable
{
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimalPlaces
    )
        ERC20(name, symbol)
    {
        _decimals = _decimalPlaces;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external onlyOwner
    {
        _mint(to, amount);
    }
}