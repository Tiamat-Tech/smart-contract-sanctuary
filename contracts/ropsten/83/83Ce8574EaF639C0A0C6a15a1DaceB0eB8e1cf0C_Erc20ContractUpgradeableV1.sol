// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
//import "hardhat/console.sol";

contract Erc20ContractUpgradeableV1 is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    bool private _type; // false - without fixAmount and percentAmount, true - with fixAmount and percentAmount
    uint256 private _fixAmount;
    address private _fixAddress;
    uint8 private _percent;
    address private _percentAddress;

    uint256 private constant _MAX_FIX_AMOUNT = 1000000000000000000000;
    uint8 private constant _MAX_PERCENT = 10;

    event UpdateType(bool typeValue);

    event UpdateFixAmount(uint256 fixAmount);

    event UpdateFixAddress(address fixAddress);

    event UpdatePercent(uint8 percent);

    event UpdatePercentAddress(address percentAddress);

    function initialize(
        string memory name_,
        string memory symbol_,
        bool type_,
        uint256 fixAmount_,
        address fixAddress_,
        uint8 percent_,
        address percentAddress_
    ) initializer external NotZeroAddress(fixAddress_) NotZeroAddress(percentAddress_)  {
        require(bytes(name_).length != 0, "Erc20ContractUpgradeableV1: Invalid name");
        require(bytes(symbol_).length != 0, "Erc20ContractUpgradeableV1: Invalid symbol");
        require(fixAmount_ <= _MAX_FIX_AMOUNT, "Erc20ContractUpgradeableV1: Invalid fix amount");
        require(percent_ <= _MAX_PERCENT, "Erc20ContractUpgradeableV1: Invalid percent");

        __ERC20_init(name_, symbol_);
        __Ownable_init();
        __ReentrancyGuard_init();

        _type = type_;
        _fixAmount = fixAmount_;
        _fixAddress = fixAddress_;
        _percent = percent_;
        _percentAddress = percentAddress_;
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function getType() external view returns (bool) {
        return _type;
    }

    function getFixAmount() external view returns (uint256) {
        return _fixAmount;
    }

    function getFixAddress() external view returns (address) {
        return _fixAddress;
    }

    function getPercent() external view returns (uint8) {
        return _percent;
    }

    function getPercentAddress() external view returns (address) {
        return _percentAddress;
    }

    function getMaxFixAmount() external view returns (uint256) {
        return _MAX_FIX_AMOUNT;
    }

    function getMaxPercent() external view returns (uint8) {
        return _MAX_PERCENT;
    }

    function updateType(bool type_) external onlyOwner {
        require(type_ != _type, "Erc20ContractUpgradeableV1: The same value is using now");
        _type = type_;
        emit UpdateType(type_);
    }

    function updateFixAmount(uint256 fixAmount_) external onlyOwner {
        require(fixAmount_ <= _MAX_FIX_AMOUNT, "Erc20ContractUpgradeableV1: Invalid fix amount");
        require(fixAmount_ != _fixAmount, "Erc20ContractUpgradeableV1: The same value is using now");
        _fixAmount = fixAmount_;
        emit UpdateFixAmount(fixAmount_);
    }

    function updateFixAddress(address fixAddress_) external onlyOwner NotZeroAddress(fixAddress_) {
        require(fixAddress_ != _fixAddress, "Erc20ContractUpgradeableV1: The same value is using now");
        _fixAddress = fixAddress_;
        emit UpdateFixAddress(fixAddress_);
    }

    function updatePercent(uint8 percent_) external onlyOwner {
        require(percent_ <= _MAX_PERCENT, "Erc20ContractUpgradeableV1: Invalid percent");
        require(percent_ != _percent, "Erc20ContractUpgradeableV1: The same value is using now");
        _percent = percent_;
        emit UpdatePercent(percent_);
    }

    function updatePercentAddress(address percentAddress_) external onlyOwner NotZeroAddress(percentAddress_) {
        require(percentAddress_ != _percentAddress, "Erc20ContractUpgradeableV1: The same value is using now");
        _percentAddress = percentAddress_;
        emit UpdatePercentAddress(percentAddress_);
    }

    function mintAmount(address account_, uint256 amount_) external onlyOwner nonReentrant NotZeroAddress(account_) {
        _mint(account_, amount_);
    }

    function transfer(address to_, uint256 amount_) public override NotZeroAddress(to_) returns (bool) {
        if (_type) {
            uint256 commissionAmount = 0;
            if (_fixAmount > 0) {
                commissionAmount += _fixAmount;
                super.transfer(_fixAddress, _fixAmount);
            }
            if (_percent > 0) {
                uint256 percentAmount = amount_ * _percent / 100;
                commissionAmount += percentAmount;
                super.transfer(_percentAddress, percentAmount);
            }
            return super.transfer(to_, amount_ - commissionAmount);
        } else {
            if (_fixAmount > 0) {
                super.transfer(_fixAddress, _fixAmount);
            }
            if (_percent > 0) {
                super.transfer(_percentAddress, amount_ * _percent / 100);
            }
            return super.transfer(to_, amount_);
        }
    }

    function transferFrom(address from_, address to_, uint256 amount_) public override NotZeroAddress(from_) NotZeroAddress(to_) returns (bool) {
        if (_type) {
            uint256 commissionAmount = 0;
            if (_fixAmount > 0) {
                commissionAmount += _fixAmount;
                super.transferFrom(from_, _fixAddress, _fixAmount);
            }
            if (_percent > 0) {
                uint256 percentAmount = amount_ * _percent / 100;
                commissionAmount += percentAmount;
                super.transferFrom(from_, _percentAddress, percentAmount);
            }

            return super.transferFrom(from_, to_, amount_ - commissionAmount);
        } else {
            if (_fixAmount > 0) {
                super.transferFrom(from_, _fixAddress, _fixAmount);
            }
            if (_percent > 0) {
                super.transferFrom(from_, _percentAddress, amount_ * _percent / 100);
            }
            return super.transferFrom(from_, to_, amount_);
        }
    }

    modifier NotZeroAddress(address account_) {
        require(account_ != address(0), "Erc20ContractUpgradeableV1: Invalid address");
        _;
    }
}