// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../manifest/ManifestAdmin.sol";

contract MapifestConfigurator is ManifestAdmin {
    uint32 private _basePrice = 100;
    uint32 private _messagePriceMultiplier = 1;
    uint32 private _imagePriceMultiplier = 3;
    uint32 private _videoPriceMultiplier = 10;
    uint32 private _profilePriceMultiplier = 50;

    uint8 public valueAmountSplitByPercentage = 70;
    uint8 public pinPriceSplitByPercentage = 30;

    constructor() ManifestAdmin() {}

    // ----- Price setting -----

    function getMessagePrice() external view returns (uint256) {
        return _getMessagePrice();
    }

    function getImagePrice() external view returns (uint256) {
        return _getImagePrice();
    }

    function getVideoPrice() external view returns (uint256) {
        return _getVideoPrice();
    }

    function getProfilePrice() external view returns (uint256) {
        return _getProfilePrice();
    }

    function _getMessagePrice() internal view returns (uint256) {
        return _basePrice * _messagePriceMultiplier;
    }

    function _getImagePrice() internal view returns (uint256) {
        return _basePrice * _imagePriceMultiplier;
    }

    function _getVideoPrice() internal view returns (uint256) {
        return _basePrice * _videoPriceMultiplier;
    }

    function _getProfilePrice() internal view returns (uint256) {
        return _basePrice * _profilePriceMultiplier;
    }

    function getPinBasePrice(uint256 _decimal) external view returns (uint256) {
        return _getPinBasePrice(_decimal);
    }

    function _getPinBasePrice(uint256 _decimal)
        internal
        view
        returns (uint256)
    {
        uint256 MAX_RESOLUTION = 8;
        uint256 unitPinPrice = (10**(MAX_RESOLUTION - _decimal + 1)); // 10 unit = 10 USD
        return _basePrice * unitPinPrice;
    }

    // ----- Administrative -----
    function adjustBasePrice(uint32 basePrice_)
        external
        onlyAdmin
    {
        _basePrice = basePrice_;
    }

    function adjustMessagePriceMultiplier(uint32 _value) external onlyAdmin {
        _messagePriceMultiplier = _value;
    }

    function adjustImagePriceMultiplier(uint32 _value) external onlyAdmin {
        _imagePriceMultiplier = _value;
    }

    function adjustVideoPriceMultiplier(uint32 _value) external onlyAdmin {
        _videoPriceMultiplier = _value;
    }

    function adjustProfilericeMultiplier(uint32 _value) external onlyAdmin {
        _profilePriceMultiplier = _value;
    }

    function adjustValueAmountSplitByPercentage(uint8 _value)
        external
        onlyAdmin
    {
        valueAmountSplitByPercentage = _value;
    }

    function adjustPinPriceSplitByPercentage(uint8 _value) external onlyAdmin {
        pinPriceSplitByPercentage = _value;
    }
}