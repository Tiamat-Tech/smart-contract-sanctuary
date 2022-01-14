// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAssetPool.sol";

contract AssetPool is IAssetPool, ERC20Upgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20;

    uint8 private _decimals;
    IERC20Upgradeable public underlyingToken;

    uint256 public adjustedTotalReward;
    uint256 public adjustedTotalWithdrawnReward;
    mapping(address => uint256) public adjustedWithdrawnReward;

    event Deposit(address indexed _from, uint _value);
    event Withdraw(address indexed _to, uint _value);
    event ClaimReward(address who, uint256 amount);
    event AccumulateReward(uint256 amount);

    function initialize(address token) public initializer {
        __ERC20_init(string(abi.encodePacked("wharf ", ERC20Upgradeable(token).name())), string(abi.encodePacked("w", ERC20Upgradeable(token).symbol())));

        underlyingToken = IERC20Upgradeable(token);
        _decimals = ERC20Upgradeable(token).decimals();
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function deposit(uint amount) external override nonReentrant returns (bool) {
        require(amount > 0, "AssetPool: amount is zero");

        IERC20Upgradeable(underlyingToken).safeTransferFrom(msg.sender, address(this), amount);

        uint256 totalShares = totalSupply();

        _mint(msg.sender, amount);

        if (totalShares != 0) {
            uint256 adjustReward = amount.mul(adjustedTotalReward).div(totalShares, "AssetPool: totalShares cannot be zero");
            adjustedTotalReward += adjustReward;
            adjustedTotalWithdrawnReward += adjustReward;
            adjustedWithdrawnReward[msg.sender] += adjustReward;
        }

        emit Deposit(msg.sender, amount);
        return true;
    }

    // onlyLending
    function withdraw(uint amount) external override nonReentrant returns (bool) {
        require(amount > 0, "AssetPool: amount is zero");
        uint256 reward = availableReward(msg.sender);
        if (reward > 0) {
            // claim reward if any
            _claim(msg.sender, reward);
        }
        uint256 shares = balanceOf(msg.sender);
        _burn(msg.sender, amount);
        IERC20Upgradeable(underlyingToken).safeTransfer(msg.sender, amount);

        uint256 adjustReward = amount.mul(adjustedWithdrawnReward[msg.sender]).div(shares, "AssetPool: shares cannot be zero");
        adjustedTotalReward -= adjustReward;
        adjustedTotalWithdrawnReward -= adjustReward;
        adjustedWithdrawnReward[msg.sender] -= adjustReward;

        emit Withdraw(msg.sender, amount);
        return true;
    }

    function availableReward(address who) public view override returns (uint256) {
        uint256 shares = balanceOf(who);
        if (shares == 0) return 0;
        uint256 totalShares = totalSupply();
        (, uint256 amount) = shares.mul(adjustedTotalReward).div(totalShares, "AssetPool: totalShares cannot be zero").trySub(adjustedWithdrawnReward[who]);
        return amount;
    }

    function claimReward() external override nonReentrant returns (bool) {
        uint256 available = availableReward(msg.sender);
        return _claim(msg.sender, available);
    }

    function _claim(address who, uint256 amount) internal returns (bool) {
        IERC20Upgradeable(underlyingToken).safeTransfer(who, amount);
        adjustedWithdrawnReward[who] += amount;
        adjustedTotalWithdrawnReward += amount;

        emit ClaimReward(who, amount);
        return true;
    }

    // onlyGateway
    function transferAsset(address to, uint256 amount) external override returns (bool) {}

    function accumulateReward(uint256 amount) external override returns (uint256) {
        uint256 totalShares = totalSupply();
        require(totalShares > 0, "AssetPool: there is no share");

        adjustedTotalReward += amount;

        emit AccumulateReward(amount);
        return adjustedTotalReward;
    }
}