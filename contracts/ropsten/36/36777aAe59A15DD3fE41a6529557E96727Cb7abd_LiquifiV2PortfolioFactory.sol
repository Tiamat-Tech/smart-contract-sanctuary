// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { PortfolioFactory } from "./interfaces/PortfolioFactory.sol";
import { GovernanceRouter } from "./interfaces/GovernanceRouter.sol";
import { LiquifiV2Portfolio } from "./LiquifiV2Portfolio.sol";

contract LiquifiV2PortfolioFactory is PortfolioFactory {
    address[] public override portfolios;
    GovernanceRouter public override governanceRouter;
    address public override weth;

    constructor(address _governanceRouter) {
        governanceRouter = GovernanceRouter(_governanceRouter);
        weth = address(GovernanceRouter(_governanceRouter).weth());
    }

    function getPortfolioCount() external override view returns (uint) {
        return portfolios.length;
    }

    function getMainPortfolio() external override view returns (address) {
        require(portfolios.length > 0, "ERROR: No portfolios have been added yet");
        return portfolios[0];
    }

    function addPortfolio(uint feeDenominator) external override returns (address portfolio){
        require(msg.sender == address(governanceRouter.governor()), "ERROR: Only governor can add portfolios");
        bool isMain = portfolios.length == 0 ? true : false;
        portfolio = address(new LiquifiV2Portfolio{ /* make portfolio address deterministic */ salt: bytes32(uint(1))}(
            isMain, portfolios.length, address(governanceRouter), feeDenominator
        ));
        portfolios.push(portfolio);
        governanceRouter.minter().addPortfolio(portfolio);
        governanceRouter.oracle().addNewPortfolio(portfolio);
    }
}