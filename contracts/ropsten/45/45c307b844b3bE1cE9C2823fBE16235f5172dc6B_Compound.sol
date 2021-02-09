// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/CTokenInterface.sol";
import "./interfaces/ComptrollerInterface.sol";
import "./interfaces/PriceOracleInterface.sol";

contract Compound {
    ComptrollerInterface public comptroller;
    PriceOracleInterface public priceOracle;

    constructor(address _comptroller, address _priceOracle) {
        comptroller = ComptrollerInterface(_comptroller);
        priceOracle = PriceOracleInterface(_priceOracle);
    }

    /**************** LENDING PART ***************/

    function supply(address cTokenAddress, uint256 underlyingAmount) external {
        CTokenInterface cToken = CTokenInterface(cTokenAddress);
        address underlyingAddress = cToken.underlying();
        IERC20(underlyingAddress).approve(cTokenAddress, underlyingAmount);
        uint256 result = cToken.mint(underlyingAmount); // if fails, it doesn't throw
        require(
            result == 0,
            "cToken#mint() failed. See Compound ErrorReporter.sol for more details"
        );
    }

    // Reedem the token plus the interest
    function redeem(address cTokenAddress, uint256 cTokenAmount) external {
        CTokenInterface cToken = CTokenInterface(cTokenAddress);
        uint256 result = cToken.redeem(cTokenAmount); // Alternatively, cToken.redeemUnderlying(redeemAmount);
        require(
            result == 0,
            "cToken#redeem() failed. See Compound ErrorReporter.sol for more details"
        );
    }

    /**************** BORROWING PART ***************/

    // to determine which token to use as collateral
    function enterMarket(address cTokenAddress) external {
        address[] memory markets = new address[](1);
        markets[0] = cTokenAddress;
        uint256[] memory results = comptroller.enterMarkets(markets);
        require(
            results[0] == 0, // because we add only 1 cToken
            "comptroller#enterMarket() failed. See Compound ErrorReporter.sol for more details"
        );
    }

    // borrow tokens (after enterMarket)
    function borrow(address cTokenAddress, uint256 borrowAmount) external {
        CTokenInterface cToken = CTokenInterface(cTokenAddress);
        //address underlyingAddress = cToken.underlying();
        uint256 result = cToken.borrow(borrowAmount);
        require(
            result == 0,
            "cToken#borrow() failed. See Compound ErrorReporter.sol for more details"
        ); // if it fails, it is likely that we don't have enough collateral
    }

    // repay the loan
    function repayBorrow(address cTokenAddress, uint256 underlyingAmount)
        external
    {
        CTokenInterface cToken = CTokenInterface(cTokenAddress);
        address underlyingAddress = cToken.underlying();
        IERC20(underlyingAddress).approve(cTokenAddress, underlyingAmount);
        uint256 result = cToken.repayBorrow(underlyingAmount);
        require(
            result == 0,
            "cToken#repayBorrow() failed. See Compound ErrorReporter.sol for more details"
        );
    }

    // Determine what is the maximum amount we can borrow for any asset
    function getMaxBorrow(address cTokenAddress)
        external
        view
        returns (uint256)
    {
        (uint256 result, uint256 liquidity, uint256 shortfall) =
            comptroller.getAccountLiquidity(address(this));
        require(
            result == 0,
            "comptroller#getAccountLiquidity() failed. See Compound ErrorReporter.sol for more details"
        );
        require(shortfall == 0, "account underwater");
        require(liquidity > 0, "account does not have collateral"); // otherwise, we are at the limit
        uint256 underlyingPrice = priceOracle.getUnderlyingPrice(cTokenAddress); // e.g.: if we pass cDAI, it will return the price of DAI
        return liquidity / underlyingPrice;
    }
}