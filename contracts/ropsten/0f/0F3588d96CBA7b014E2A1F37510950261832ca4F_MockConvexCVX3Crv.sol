// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";


contract MockConvexCVX3Crv is ERC20 {
    constructor() public ERC20("Curve.fi DAI/USDC/USDT Convex Deposit", "cvx3Crv") {}

    function mint(address user, uint256 value) public virtual returns (bool) {
        _mint(user, value);

        return true;
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}