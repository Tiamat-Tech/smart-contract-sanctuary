// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITokenSaleFactory.sol";
import "./TokenSale.sol";

/// @title TokenSaleFactory contract.
contract TokenSaleFactory is ITokenSaleFactory, Ownable {
    address[] public contracts;

    /// @notice Return total sales contract count.
    function getContractsCount() external view override returns (uint256) {
        return contracts.length;
    }

    /// @notice Create new TokenSale contract.
    /// @param _buyStartTimestamp Timestamp.
    /// @param _withdrawTimestamp Timestamp.
    function create(
        uint64 _buyStartTimestamp,
        uint64 _withdrawTimestamp
    ) external override onlyOwner {
        TokenSale _contract = new TokenSale(_buyStartTimestamp, _withdrawTimestamp);
        _contract.transferOwnership(owner());

        contracts.push(address(_contract));

        emit TokenSaleCreated(address(_contract));
    }
}