// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockCurve3Crv is ERC20, Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public underlyTokens;
    address public target;

    event SwapToken(address indexed user, uint256 amount);

    function setTarget(address _target) public onlyOwner {
        target = _target;
    }

    function addUnderlyToken(address _token) public onlyOwner {
        require(!underlyTokens[_token], "!token");

        underlyTokens[_token] = true;
    }

    function swapToken(address _underlyToken, uint256 _amount) public {
        require(underlyTokens[_underlyToken], "!underlyToken");

        IERC20(_underlyToken).safeTransferFrom(msg.sender, target, _amount);

        mint(msg.sender, _amount * 1e12);

        emit SwapToken(msg.sender, _amount * 1e12);
    }

    constructor() public ERC20("Curve.fi DAI/USDC/USDT", "3Crv") {}

    function mint(address user, uint256 value) public virtual returns (bool) {
        _mint(user, value);

        return true;
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}