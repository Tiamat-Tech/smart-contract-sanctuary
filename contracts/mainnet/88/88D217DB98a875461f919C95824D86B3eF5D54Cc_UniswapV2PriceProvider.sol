// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IPriceOracle.sol";
import "../misc/SafeMath.sol";
import "../misc/Math.sol";

/** @title UniswapV2PriceProvider
 * @notice Price provider for a Uniswap V2 pair token
 * It calculates the price using Chainlink as an external price source and the pair's tokens reserves using the weighted arithmetic mean formula.
 * If there is a price deviation, instead of the reserves, it uses a weighted geometric mean with the constant invariant K.
 */

contract UniswapV2PriceProvider {
    using SafeMath for uint256;

    IUniswapV2Pair public immutable pair;
    address[] public tokens;
    bool[] public isPeggedToEth;
    uint8[] public decimals;
    IPriceOracle immutable priceOracle;
    uint256 public immutable maxPriceDeviation;

    /**
     * UniswapV2PriceProvider constructor.
     * @param _pair Uniswap V2 pair address.
     * @param _isPeggedToEth For each token, true if it is pegged to ETH.
     * @param _decimals Number of decimals for each token.
     * @param _priceOracle Aave price oracle.
     * @param _maxPriceDeviation Threshold of spot prices deviation: 10ˆ16 represents a 1% deviation.
     */
    constructor(
        IUniswapV2Pair _pair,
        bool[] memory _isPeggedToEth,
        uint8[] memory _decimals,
        IPriceOracle _priceOracle,
        uint256 _maxPriceDeviation
    ) public {
        require(_isPeggedToEth.length == 2, "ERR_INVALID_PEGGED_LENGTH");
        require(_decimals.length == 2, "ERR_INVALID_DECIMALS_LENGTH");
        require(
            _decimals[0] <= 18 && _decimals[1] <= 18,
            "ERR_INVALID_DECIMALS"
        );
        require(
            address(_priceOracle) != address(0),
            "ERR_INVALID_PRICE_PROVIDER"
        );
        require(_maxPriceDeviation < Math.BONE, "ERR_INVALID_PRICE_DEVIATION");

        pair = _pair;
        //Get tokens
        tokens.push(_pair.token0());
        tokens.push(_pair.token1());
        isPeggedToEth = _isPeggedToEth;
        decimals = _decimals;
        priceOracle = _priceOracle;
        maxPriceDeviation = _maxPriceDeviation;
    }

    /**
     * Returns the token balance in ethers by multiplying its reserves with its price in ethers.
     * @param index Token index.
     * @param reserve Token reserves.
     */
    function getEthBalanceByToken(uint256 index, uint112 reserve)
        internal
        view
        returns (uint256)
    {
        uint256 pi = isPeggedToEth[index]
            ? Math.BONE
            : uint256(priceOracle.getAssetPrice(tokens[index]));
        require(pi > 0, "ERR_NO_ORACLE_PRICE");
        uint256 missingDecimals = uint256(18).sub(decimals[index]);
        uint256 bi = uint256(reserve).mul(10**(missingDecimals));
        return Math.bmul(bi, pi);
    }

    /**
     * Returns true if there is a price deviation.
     * @param ethTotal_0 Total eth for token 0.
     * @param ethTotal_1 Total eth for token 1.
     */
    function hasDeviation(uint256 ethTotal_0, uint256 ethTotal_1)
        internal
        view
        returns (bool)
    {
        //Check for a price deviation
        uint256 price_deviation = Math.bdiv(ethTotal_0, ethTotal_1); 
        if (
            price_deviation > (Math.BONE.add(maxPriceDeviation)) ||
            price_deviation < (Math.BONE.sub(maxPriceDeviation))
        ) {
            return true;
        }
        price_deviation = Math.bdiv(ethTotal_1, ethTotal_0);
        if (
            price_deviation > (Math.BONE.add(maxPriceDeviation)) ||
            price_deviation < (Math.BONE.sub(maxPriceDeviation))
        ) {
            return true;
        }
        return false;
    }

    /**
     * Calculates the price of the pair token using the formula of arithmetic mean.
     * @param ethTotal_0 Total eth for token 0.
     * @param ethTotal_1 Total eth for token 1.
     */
    function getArithmeticMean(uint256 ethTotal_0, uint256 ethTotal_1)
        internal
        view
        returns (uint256)
    {
        uint256 totalEth = ethTotal_0 + ethTotal_1;
        return Math.bdiv(totalEth, getTotalSupplyAtWithdrawal());
    }

    /**
     * Calculates the price of the pair token using the formula of weighted geometric mean.
     * @param ethTotal_0 Total eth for token 0.
     * @param ethTotal_1 Total eth for token 1.
     */
    function getWeightedGeometricMean(uint256 ethTotal_0, uint256 ethTotal_1)
        internal
        view
        returns (uint256)
    {
        uint256 square = Math.bsqrt(Math.bmul(ethTotal_0, ethTotal_1), true);
        return
            Math.bdiv(
                Math.bmul(Math.TWO_BONES, square),
                getTotalSupplyAtWithdrawal()
            );
    }

    /**
     * Returns the pair's token price.
     * It calculates the price using Chainlink as an external price source and the pair's tokens reserves using the arithmetic mean formula.
     * If there is a price deviation, instead of the reserves, it uses a weighted geometric mean with constant invariant K.
     */
    function latestAnswer() external view returns (uint256) {
        //Get token reserves in ethers
        (uint112 reserve_0, uint112 reserve_1, ) = pair.getReserves();
        uint256 ethTotal_0 = getEthBalanceByToken(0, reserve_0);
        uint256 ethTotal_1 = getEthBalanceByToken(1, reserve_1);

        if (hasDeviation(ethTotal_0, ethTotal_1)) {
            //Calculate the weighted geometric mean
            return getWeightedGeometricMean(ethTotal_0, ethTotal_1);
        } else {
            //Calculate the arithmetic mean
            return getArithmeticMean(ethTotal_0, ethTotal_1);
        }
    }

    
    /**
     * Returns Uniswap V2 pair total supply at the time of withdrawal.
     */
    function getTotalSupplyAtWithdrawal()
        private
        view
        returns (uint256 totalSupply)
    {
        totalSupply = pair.totalSupply();
        address feeTo = IUniswapV2Factory(IUniswapV2Pair(pair).factory())
            .feeTo();
        bool feeOn = feeTo != address(0);
        if (feeOn) {
            uint256 kLast = IUniswapV2Pair(pair).kLast();
            if (kLast != 0) {
                (uint112 reserve_0, uint112 reserve_1, ) = pair.getReserves();
                uint256 rootK = Math.bsqrt(
                    uint256(reserve_0).mul(reserve_1),
                    false
                );
                uint256 rootKLast = Math.bsqrt(kLast, false);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    uint256 liquidity = numerator / denominator;
                    totalSupply = totalSupply.add(liquidity);
                }
            }
        }
    }

    /**
     * Returns Uniswap V2 pair address.
     */
    function getPair() external view returns (IUniswapV2Pair) {
        return pair;
    }

    /**
     * Returns all tokens.
     */
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }
}