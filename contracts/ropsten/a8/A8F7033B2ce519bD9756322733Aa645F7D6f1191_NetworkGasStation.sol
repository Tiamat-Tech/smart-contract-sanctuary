// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NetworkGasStation  is Ownable, ReentrancyGuard {
    string private _name;

    uint256 private _averageGasPrice;
    uint32 private _averageGas;

    mapping(address => bool) private _admins;

    event AddToAdmins(address indexed account);

    event RemoveFromAdmins(address indexed account);

    event UpdateAverageGasPrice(uint256 averageGasPrice);

    event UpdateAverageGas(uint32 averageGas);

    constructor(string memory name_, uint256 averageGasPrice_, uint32 averageGas_) {
        _name = name_;
        _averageGasPrice = averageGasPrice_;
        _averageGas = averageGas_;
    }

    function getName() external view returns (string memory) {
        return _name;
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function getAverageGasPrice() external view returns (uint256) {
        return _averageGasPrice;
    }

    function getAverageGas() external view returns (uint32) {
        return _averageGas;
    }

    function checkAdmin(address account_) external view returns (bool) {
        return _admins[account_];
    }

    function addAdmin(address account_) external onlyOwner NotZeroAddress(account_) {
        _admins[account_] = true;
        emit AddToAdmins(account_);
    }

    function removedAdmin(address account_) external onlyOwner NotZeroAddress(account_) {
        _admins[account_] = false;
        emit RemoveFromAdmins(account_);
    }

    function updateAverageGasPrice(address account_, uint256 averageGasPrice_) external isAdmin(account_) {
        require(averageGasPrice_ != 0, "NetworkGasStation: Invalid averageGasPrice");
        require(averageGasPrice_ != _averageGasPrice, "NetworkGasStation: The same value is using now");
        _averageGasPrice = averageGasPrice_;
        emit UpdateAverageGasPrice(averageGasPrice_);
    }

    function updateAverageGas(address account_, uint32 averageGas_) external isAdmin(account_) {
        require(averageGas_ != 0, "NetworkGasStation: Invalid averageGas");
        require(averageGas_ != _averageGas, "NetworkGasStation: The same value is using now");
        _averageGas = averageGas_;
        emit UpdateAverageGas(averageGas_);
    }

    modifier isAdmin(address account_) {
        require(_admins[account_], "NetworkGasStation: Address is not admin");
        _;
    }

    modifier NotZeroAddress(address account_) {
        require(account_ != address(0), "NetworkGasStation: Invalid address");
        _;
    }
}