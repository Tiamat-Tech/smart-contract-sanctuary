// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IAssetPool.sol";

contract AssetPool is IAssetPool, ERC20 {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint8 private _decimals;
    IERC20 public underlyingToken;
    // uint private totalReward;
    // mapping(address => uint) private rewardStartingPoint;

    event Deposit(address indexed _from, uint _value);
    event Withdraw(address indexed _to, uint _value);

    constructor(address token)
    ERC20(
        string(abi.encodePacked("wharf ", ERC20(token).name())),
        string(abi.encodePacked("w", ERC20(token).symbol()))
    ) {
        underlyingToken = IERC20(token);
        _decimals = ERC20(token).decimals();
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function deposit(address who, uint amount) external override returns (bool) {
        underlyingToken.transferFrom(who, address(this), amount);
        _mint(who, amount);
        emit Deposit(who, amount);
        return true;
    }

    // onlyLending
    function withdraw(address who, uint amount) external override returns (bool) {
        underlyingToken.transfer(who, amount);
        _burn(who, amount);
        emit Withdraw(who, amount);
        return true;
    }

    function availableReward(address who) external view override returns (uint) {}
    function claimReward(address who, uint amount) external override returns (uint) {}

    // onlyGateway
    function transferAsset(address to, uint amount) external override returns (bool) {}
}