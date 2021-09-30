// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/yearn/IVault.sol";
import "../interfaces/yearn/IYRegistry.sol";

contract YRegistry is IYRegistry, Ownable {
    IERC20[] _tokens;
    mapping(address => IVault[]) _vaults;

    function addToken(IERC20 token) external onlyOwner returns (bool success) {
        _tokens.push(token);
        return true;
    }

    function addVault(address token, IVault vault) external onlyOwner returns (bool success) {
        _vaults[token].push(vault);
        return true;
    }

    function numTokens() external view override returns (uint256) {
        return _tokens.length;
    }

    function tokens(uint256 index) external view override returns (address vault) {
        return address(_tokens[index]);
    }

    function numVaults(address token) external view override returns (uint256) {
        return _vaults[token].length;
    }

    function vaults(address token, uint256 index) external view override returns (address vault) {
        return address(_vaults[token][index]);
    }
}