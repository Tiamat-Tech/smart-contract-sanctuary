// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/ITrading.sol";
import "hardhat/console.sol";

/// @title Auction Contract
/// @dev Contract for create/edit/delete trade lots
/// @dev Only Marketplace contract can use functions that change trade lots entity

contract Trading is ITrading, AccessControlUpgradeable {
    bytes32 public constant OWNER_TRADING_ROLE =
        keccak256("OWNER_TRADING_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    mapping(uint256 => TradeLot) internal _tradeLots;
    uint256 public override lastId;

    /// @dev Check if caller is contract owner

    modifier onlyOwner() {
        require(
            hasRole(OWNER_TRADING_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }

    /// @dev Check if caller is marketplace contract

    modifier onlyMarketplace() {
        require(
            hasRole(MARKETPLACE_ROLE, msg.sender),
            "Caller is not a marketplace"
        );
        _;
    }

    /// @notice Contract initialization
    /// @dev Sets main dependencies and constants
    /// @param _marketplace marketplace contract address
    /// @return true if initialization complete success

    function init(address _marketplace) external initializer returns (bool) {
        _setupRole(OWNER_TRADING_ROLE, msg.sender);
        _setRoleAdmin(OWNER_TRADING_ROLE, OWNER_TRADING_ROLE);
        _setRoleAdmin(MARKETPLACE_ROLE, OWNER_TRADING_ROLE);
        _setupRole(MARKETPLACE_ROLE, _marketplace);

        return true;
    }

    /// @notice Return full information about trade lot
    /// @dev Returns lot object by lot id
    /// @param lotId id of lot
    /// @return _lot lot object with all contains params

    function getLotById(uint256 lotId)
        external
        view
        override
        returns (ITrading.TradeLot memory _lot)
    {
        _lot = _tradeLots[lotId];
    }

    /// @notice Get owner
    /// @dev Return owner by lot id
    /// @param lotId id of lot
    /// @return lotCreator address of lot creator

    function getOwner(uint256 lotId)
        external
        view
        override
        returns (address lotCreator)
    {
        lotCreator = _tradeLots[lotId].lotCreator;
    }

    /// @notice Adds trade lot
    /// @dev Adds trade object in mapping at contract
    /// @param lotCreator address of lot creator
    /// @param tokenId id of token in lot
    /// @param price price for single token in lot
    /// @param amount amount of tokens in current lot
    /// @param endTime timestamp when auction end
    /// @return lotId id of current lot

    function addTradeLot(
        address lotCreator,
        uint256 tokenId,
        uint256 price,
        uint128 amount,
        uint128 endTime
    ) external override onlyMarketplace returns (uint256 lotId) {
        _tradeLots[lastId] = TradeLot(
            lotCreator,
            tokenId,
            price,
            amount,
            endTime
        );
        lotId = lastId;
        lastId = lastId + 1;

        return lotId;
    }

    /// @notice Change token amount in lot
    /// @dev Sets new amount of token in trade lot object
    /// @param lotId lot id
    /// @param amount new amount of tokens

    function changeAmount(uint256 lotId, uint128 amount)
        external
        override
        onlyMarketplace
    {
        _tradeLots[lotId].amount = amount;
    }

    /// @notice Edit trade lot
    /// @dev Possible edit only price, amount, endTime
    /// @dev If some of params are will not change, should give them their previous value
    /// @param lotId id of lot
    /// @param price new or previous amount value
    /// @param amount new or previous startPrice value
    /// @param endTime new or previous startPrice value

    function editTradeLot(
        uint256 lotId,
        uint256 price,
        uint128 amount,
        uint128 endTime
    ) external override onlyMarketplace {
        if (_tradeLots[lotId].amount != amount) {
            _tradeLots[lotId].amount = amount;
        }
        if (_tradeLots[lotId].price != price) {
            _tradeLots[lotId].price = price;
        }
        if (_tradeLots[lotId].endTime != endTime) {
            _tradeLots[lotId].endTime = endTime;
        }
    }

    /// @notice Delete trade from contract
    /// @dev Remove trade object by id from mapping
    /// @param lotId id of trade lot, that should delete

    function delTradeLot(uint256 lotId) external override onlyMarketplace {
        delete _tradeLots[lotId];
    }
}