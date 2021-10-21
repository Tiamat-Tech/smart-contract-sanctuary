// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract DTF is ERC20, ERC20Burnable, Ownable {
    uint256 private constant INITIAL_SUPPLY = 500 * 10**(6 + 18); // 500M tokens
    constructor(
        address _owner,
        string memory _tokenName ,//= "DTF Game",
        string memory _tokenSymbol //= "DTF"
    )ERC20(_tokenName, _tokenSymbol) {
        _mint(_owner, INITIAL_SUPPLY);
        transferOwnership(_owner);
    }
}