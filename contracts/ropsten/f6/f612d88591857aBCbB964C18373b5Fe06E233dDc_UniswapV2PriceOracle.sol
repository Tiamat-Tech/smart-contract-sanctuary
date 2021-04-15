// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.6.0;

import './libraries/UQ112x112.sol';
import './libraries/PhutureLibrary.sol';
import './libraries/SafeMath.sol';
import './libraries/TransferHelper.sol';

import './interfaces/IIndex.sol';
import './interfaces/IIndexFactory.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IUniswapV2PriceOracle.sol';

// TODO: check is this can be optimized by merging PhutureFactory+IndexFund

contract UniswapV2PriceOracle is IUniswapV2PriceOracle {
    using SafeMath for uint;
    using UQ112x112 for uint224;

    struct PriceFactor {
        uint32 blockTimestampLast; // uses single storage slot, accessible via getReserves

        uint priceCumulativeLast; // USD / quote * dt

        uint lastPriceCumulativeLast;
        uint tempPriceCumulativeLast;

        uint indexPrice;

        uint32 lastPriceCumulativeLastBlockTimestamp;          // uses single storage slot: 160 + 32 = 192 / 256
        uint32 tempPriceCumulativeLastBlockTimestamp;          // uses single storage slot: 160 + 32 + 32 = 224 / 256
        uint32 priceOracleInterval;                            // uses single storage slot: 160 + 32 + 32 + 32 = 256 / 256
    }
    
    address public override factory;
    address public override usd;

    mapping(address => PriceFactor) private priceFactors;

    constructor () public {
        
    }

    function initialize(address _factory, address _usd) external override {
        factory = _factory;
        usd = _usd;
    }

    function getPairInfo(address asset) internal view returns (uint32 _timestamp, uint256 _cumulativeLast) {
        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(IIndexFactory(factory).exchangeFactory());
        IUniswapV2Pair pair = IUniswapV2Pair(uniswapFactory.getPair(usd, asset));

        (,, _timestamp) = pair.getReserves();
        _cumulativeLast = usd == pair.token0() ? pair.price0CumulativeLast() : pair.price1CumulativeLast();
    }
    // update reserves and, on the first call per block, price accumulators
    function getPrice(address asset) external override returns(uint price) {
        PriceFactor storage priceFactor = priceFactors[asset];

        (priceFactor.blockTimestampLast, priceFactor.priceCumulativeLast) = getPairInfo(asset);

        uint oracleTimeElapsed = priceFactor.blockTimestampLast - priceFactor.tempPriceCumulativeLastBlockTimestamp;
        if (oracleTimeElapsed > priceFactor.priceOracleInterval) {
            priceFactor.lastPriceCumulativeLast = priceFactor.tempPriceCumulativeLast;
            priceFactor.lastPriceCumulativeLastBlockTimestamp = priceFactor.tempPriceCumulativeLastBlockTimestamp;
            priceFactor.tempPriceCumulativeLast = priceFactor.priceCumulativeLast;
            priceFactor.tempPriceCumulativeLastBlockTimestamp = priceFactor.blockTimestampLast;
        }
       
        (uint _priceUSDInQuoteUQ, uint32 _timeInterval) = priceUSDInQuoteUQ(asset);
        if (_timeInterval > 0) { 
            priceFactor.indexPrice = _priceUSDInQuoteUQ;
        }
        return priceFactor.indexPrice;
    }

    function setPriceOracleInterval(address asset, uint32 _priceOracleInterval) external override {
        require(_priceOracleInterval > 0, 'Phuture: INVALID');
        priceFactors[asset].priceOracleInterval = _priceOracleInterval;
        // TODO: check how interval change affects priceUSDInQuoteUQ
    }

    /// @dev external caller must check _timeInterval != 0 to ensure that price is correct
    /// @dev _timeInterval can be 0 when block.timestamp % 2**32 == 0 which results in 0 price 
    /// @return _priceUSDInQuoteUQ in UQ, TWOP for _timeElapsed interval
    /// @return _timeElapsed in seconds, time elapsed since the last oracle check

    function priceUSDInQuoteUQ(address asset) public view returns (uint _priceUSDInQuoteUQ, uint32 _timeElapsed) {
        PriceFactor storage priceFactor = priceFactors[asset];

        (uint32 blockTimestampLast, uint256 priceCumulativeLast) = getPairInfo(asset);

        _timeElapsed = blockTimestampLast - priceFactor.lastPriceCumulativeLastBlockTimestamp;
        _priceUSDInQuoteUQ = _timeElapsed > 0 ? (priceCumulativeLast - priceFactor.lastPriceCumulativeLast) / _timeElapsed : 0;
    }
}