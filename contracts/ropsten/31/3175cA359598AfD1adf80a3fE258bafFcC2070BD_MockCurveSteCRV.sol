// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockCurveSteCRV is ERC20, Ownable {
    using SafeERC20 for IERC20;

    address public target;

    event SwapToken(address indexed user, uint256 amount);

    function setTarget(address _target) public onlyOwner {
        target = _target;
    }

    function swapToken() public payable {
        require(msg.value > 0, "!ether");

        mint(msg.sender, msg.value);

        emit SwapToken(msg.sender, msg.value);
    }

    constructor() public ERC20("Curve.fi ETH/stETH", "steCRV") {}

    function mint(address user, uint256 value) public virtual returns (bool) {
        _mint(user, value);

        return true;
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}