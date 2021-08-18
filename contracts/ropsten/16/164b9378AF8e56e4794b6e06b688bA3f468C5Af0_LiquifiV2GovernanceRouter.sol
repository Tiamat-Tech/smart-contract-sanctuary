// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { GovernanceRouter } from "./interfaces/GovernanceRouter.sol";
import { WETH } from "./interfaces/WETH.sol";
import { PortfolioFactory } from "./interfaces/PortfolioFactory.sol";
import { Oracle } from "./interfaces/Oracle.sol";
import { Minter } from "./interfaces/Minter.sol";

contract LiquifiV2GovernanceRouter is GovernanceRouter {

    address public immutable override creator;
    WETH public immutable override weth;

    PortfolioFactory public override portfolioFactory;
    Oracle public override oracle;
    Minter public override minter;

    address public override governor;

    constructor(address _weth) {
        creator = tx.origin;
        weth = WETH(_weth);
    }

    function setGovernor(address _governor) external override {
        require(msg.sender == governor || (governor == address(0) && tx.origin == creator), "LIQUIFI_GVR: INVALID GOVERNANCE SENDER");
        governor = _governor;
        emit GovernorChanged(_governor);
    }

    function setPortfolioFactory(PortfolioFactory _portfolioFactory) external override {
        require(msg.sender == governor || (address(portfolioFactory) == address(0) && tx.origin == creator), "LIQUIFI_GVR: INVALID INIT SENDER");
        portfolioFactory = _portfolioFactory;
        emit PortfolioFactoryChanged(address(_portfolioFactory));
    }

    function setOracle(Oracle _oracle) external override {
        require(msg.sender == governor || (address(oracle) == address(0) && tx.origin == creator), "LIQUIFI_GVR: INVALID INIT SENDER");
        oracle = _oracle;
        emit OracleChanged(address(_oracle));
    }

    function setMinter(Minter _minter) external override {
        require(msg.sender == governor || (address(minter) == address(0) && tx.origin == creator), "LIQUIFI_GVR: INVALID INIT SENDER");
        minter = _minter;
        emit MinterChanged(address(_minter));
    }
}