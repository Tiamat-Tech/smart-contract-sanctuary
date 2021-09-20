// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/ITrading.sol";
import "hardhat/console.sol";

contract Trading is ITrading, AccessControlUpgradeable {
    bytes32 public constant OWNER_TRADING_ROLE =
        keccak256("OWNER_TRADING_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    mapping(uint256 => TradeLot) internal _tradeLots;
    uint256 public _nextId;

    function init(address _marketplace) external initializer returns (bool) {
        _setupRole(OWNER_TRADING_ROLE, msg.sender);
        _setRoleAdmin(OWNER_TRADING_ROLE, OWNER_TRADING_ROLE);
        _setRoleAdmin(MARKETPLACE_ROLE, OWNER_TRADING_ROLE);
        _setupRole(MARKETPLACE_ROLE, _marketplace);

        return true;
    }

    modifier onlyOwner() {
        require(
            hasRole(OWNER_TRADING_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }

    modifier onlyMarketplace() {
        require(
            hasRole(MARKETPLACE_ROLE, msg.sender),
            "Caller is not a marketplace"
        );
        _;
    }

    function getCurrentLotId() external view override returns (uint256 id) {
        return _nextId;
    }

    function addTradeLot(
        address lotCreator,
        uint256 tokenId,
        uint256 price,
        uint128 amount,
        uint128 endTime
    ) external override onlyMarketplace returns (uint256 lotId) {
        _tradeLots[_nextId] = TradeLot(
            lotCreator,
            tokenId,
            price,
            amount,
            endTime
        );
        lotId = _nextId;
        _nextId = _nextId + 1;

        return lotId;
    }

    function editTradeLot(
        uint256 lotId,
        uint256 price,
        uint128 amount,
        uint128 endTime
    ) external override {
        _tradeLots[lotId].amount = amount;
        _tradeLots[lotId].price = price;
        _tradeLots[lotId].endTime = endTime;
    }

    function delTradeLot(uint256 lotId) external override onlyMarketplace {
        delete _tradeLots[lotId];
    }

    function getLotById(uint256 lotId)
        external
        view
        override
        returns (ITrading.TradeLot memory _lot)
    {
        _lot = _tradeLots[lotId];
    }

    function changeAmount(uint256 lotId, uint128 amount) external override {
        _tradeLots[lotId].amount = amount;
    }

    function getOwner(uint256 lotId)
        external
        view
        override
        returns (address lotCreator)
    {
        lotCreator = _tradeLots[lotId].lotCreator;
    }
}