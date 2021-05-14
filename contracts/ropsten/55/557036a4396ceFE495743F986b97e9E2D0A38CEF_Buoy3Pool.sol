// SPDX-License-Identifier: AGPLv3
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../interfaces/IBuoy.sol";
import "../../interfaces/IERC20Detailed.sol";
import {ICurve3Pool} from "../../interfaces/ICurve.sol";
import "../../interfaces/IChainPrice.sol";
import "../../common/Whitelist.sol";
import "../../common/DecimalConstants.sol";

/// @notice Contract for calculating prices of underlying assets and LP tokens in Curve pool. Also
///     used to sanity check pool against external oracle, to ensure that pools underlying coin ratios 
///     are within a specific range (measued in BP) of the external oracles coin price ratios.
contract Buoy3Pool is IBuoy, Whitelist, DecimalConstants {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 TIME_LIMIT = 3000;
    uint256 public BASIS_POINTS = 1000;

    uint256 public constant override N_COINS = 3;
    // DAI, USDC, USDT
    address[] public override tokens;
    // ['0x6B175474E89094C44Da98b954EedeAC495271d0F',
    // '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    // '0xdAC17F958D2ee523a2206206994597C13D831ec7'];
    // TODO: Change for mainnet?

    // address threePool = '0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7';
    // ICurvePool public curvePool = ICurvePool(threePool);
    ICurve3Pool public override curvePool;
    IChainPrice public chainOracle;
    IERC20 lpToken;
    // [10**18, 10**6, 10**6]
    mapping(uint256 => uint256) public override decimals;

    event LogNewBasisPointLimit(uint256 oldLimit, uint256 newLimit);
    event LogCurvePoolAdded(address indexed curvpool, address indexed lpToken, address[] tokens);

    constructor(address _chainOracle) public {
        chainOracle = IChainPrice(_chainOracle);
    }

    /// @notice Set limit for how much Curve pool and external oracle is allowed
    ///     to deviate before failing transactions
    /// @param newLimit New limit in BP
    function setBasisPointsLmit(uint256 newLimit) external onlyGovernance {
        uint256 oldLimit = BASIS_POINTS;
        BASIS_POINTS = newLimit;
        emit LogNewBasisPointLimit(oldLimit, newLimit);
    }

    /// @notice Check the health of the Curve pool:
    ///     Ratios are checked by the following heuristic:
    ///     Orcale A - Curve
    ///     Oracle B - External oracle
    ///     Both oracles establish ratios for a set of stable coins
    ///         (a, b, c)
    ///     and product the following set of ratios:
    ///         (a/a, a/b, a/c), (b/b, b/a, b/c), (c/c, c/a, c/b)
    ///     It's simply to reduce the number of comparisons to be made
    ///     in order to have complete coverage of the system ratios:
    ///         1) ratios between a stable coin and itself can be discarded
    ///         2) inverted ratios, a/b bs b/a, while producing different results
    ///             should both reflect the same change in any one of the two 
    ///             underlying assets, but in opposite directions
    ///     This mean that the following set should provide the necessary coverage checks
    ///     to establish that the coins pricing is healthy:
    ///         (a/b, a/c, b/c)
    function safetyCheck() external view override returns (bool) {
        for (uint256 i = 0; i < N_COINS; i++) {
            for (uint256 j = i.add(1); j < N_COINS; j++) {
                if (ratioCheck(i, j) > BASIS_POINTS) return false;
            }
        }
        return true;
    }

    /// @notice Set Curve pool from which to get price ratios
    /// @param _curvePool Target Curve pool
    function setCurvePool(address _curvePool, address _lpToken) external onlyGovernance {
        require(_curvePool != address(0), "setCurvePool: Invalid address");
        curvePool = ICurve3Pool(_curvePool);
        lpToken = IERC20(_lpToken);
        address[] memory _tokens = new address[](N_COINS);
        for (uint256 i = 0; i < N_COINS; i++) {
            address token = curvePool.coins(uint128(i));
            _tokens[i] = token;
            decimals[i] = uint256(10)**IERC20Detailed(token).decimals();
        }
        tokens = _tokens;
        emit LogCurvePoolAdded(_curvePool, _lpToken, _tokens);
    }

    /// @notice Get current pool token ratios
    /// @param i Token in
    /// @param j Token out
    function _getTokenRatio(uint256 i, uint256 j) private view returns (uint256) {
        if (i == j) {
            return decimals[i];
        } else {
            // Get j amount for i tokens
            return curvePool.get_dy_underlying(int128(i), int128(j), decimals[i]);
        }
    }

    /// @notice Get USD value for a specific input amount of tokens, slippage included
    function stableToUsd(uint256[] calldata inAmounts, bool deposit)
        external
        view
        override
        returns (uint256)
    {
        return _stableToUsd(inAmounts, deposit);
    }

    /// @notice Get estimate USD price of a stablecoin amount
    /// @param inAmount Token amount
    /// @param i Index of token
    function singleStableToUsd(uint256 inAmount, uint256 i)
        external
        view
        override
        returns (uint256)
    {
        uint256[] memory inAmounts = new uint256[](N_COINS);
        inAmounts[i] = inAmount;
        return _stableToUsd(inAmounts, true);
    }

    /// @notice Get LP token value of input amount of tokens
    function stableToLp(uint256[] calldata tokenAmounts, bool deposit)
        external
        view
        override
        returns (uint256)
    {
        return _stableToLp(tokenAmounts, deposit);
    }

    /// @notice Get LP token value of input amount of single token
    function singleStableFromUsd(uint256 inAmount, int128 i)
        external
        view
        override
        returns (uint256)
    {
        return _singleStableFromLp(_usdToLp(inAmount), i);
    }

    /// @notice Get LP token value of input amount of single token
    function singleStableFromLp(uint256 inAmount, int128 i)
        external
        view
        override
        returns (uint256)
    {
        return _singleStableFromLp(inAmount, i);
    }

    /// @notice Get USD price of LP tokens you receive for a specific input amount of tokens, slippage included
    function lpToUsd(uint256 inAmount) external view override returns (uint256) {
        return _lpToUsd(inAmount);
    }

    /// @notice Convert USD amount to LP tokens
    function usdToLp(uint256 inAmount) external view override returns (uint256) {
        return _usdToLp(inAmount);
    }

    /// @notice Split LP token amount to balance of pool tokens
    /// @param inAmount Amount of LP tokens
    /// @param totalBalance Total balance of pool
    function poolBalances(uint256 inAmount, uint256 totalBalance)
        internal
        view
        returns (uint256[] memory balances)
    {
        uint256[] memory _balances = new uint256[](N_COINS);
        for (uint256 i = 0; i < N_COINS; i++) {
            _balances[i] = (IERC20(tokens[i]).balanceOf(address(curvePool)).mul(inAmount)).div(
                totalBalance
            );
        }
        balances = _balances;
    }

    /// @notice Retrieve token ratio from external oracle
    /// @param token0 Token in
    /// @param token1 Token out
    function getRatio(uint256 token0, uint256 token1)
        external
        view
        override
        returns (uint256, uint256)
    {
        (uint256 _ratio, uint256 _decimals) = chainOracle.getRatio(token0, token1);
        return (_ratio, _decimals);
    }

    /// @notice Get the underlying token balances of the curve pool
    /// @param inAmount LP amount to split into target amounts
    /// @return outAmounts Input amount split into underlying pool balance
    function balancedCalculation(uint256 inAmount)
        external
        view
        override
        returns (uint256[] memory outAmounts)
    {
        uint256[] memory _outAmounts = new uint256[](N_COINS);
        _outAmounts = poolBalances(inAmount, lpToken.totalSupply());
        outAmounts = _outAmounts;
    }

    /// @notice Sanity check the ratio of the LP token against an oracle
    /// @param token0 Token in
    /// @param token1 Token out
    function ratioCheck(uint256 token0, uint256 token1) public view returns (uint256) {
        uint256 _ratio = _getTokenRatio(token0, token1);
        uint256 _decimals = decimals[token1];
        (uint256 checkRatio, uint256 checkDecimals) = chainOracle.getRatio(token0, token1);
        require(_decimals == checkDecimals, "ratioCheck: !decimals");
        uint256 outRatio = abs(int256(_ratio - checkRatio)).mul(10000).div(_decimals);
        return outRatio;
    }

    function getVirtualPrice() external view override returns (uint256) {
        return curvePool.get_virtual_price();
    }

    // Internal functions
    function _lpToUsd(uint256 inAmount) internal view returns (uint256) {
        return inAmount.mul(curvePool.get_virtual_price()).div(DEFAULT_DECIMALS_FACTOR);
    }

    function _stableToUsd(uint256[] memory tokenAmounts, bool deposit)
        internal
        view
        returns (uint256)
    {
        require(tokenAmounts.length == N_COINS, "deposit: !length");
        uint256[N_COINS] memory _tokenAmounts;
        for (uint256 i = 0; i < N_COINS; i++) {
            _tokenAmounts[i] = tokenAmounts[i];
        }
        uint256 lpAmount = curvePool.calc_token_amount(_tokenAmounts, deposit);
        return _lpToUsd(lpAmount);
    }

    function _stableToLp(uint256[] memory tokenAmounts, bool deposit)
        internal
        view
        returns (uint256)
    {
        require(tokenAmounts.length == N_COINS, "deposit: !length");
        uint256[N_COINS] memory _tokenAmounts;
        for (uint256 i = 0; i < N_COINS; i++) {
            _tokenAmounts[i] = tokenAmounts[i];
        }
        return curvePool.calc_token_amount(_tokenAmounts, deposit);
    }

    function _singleStableFromLp(uint256 inAmount, int128 i) internal view returns (uint256) {
        uint256 result = curvePool.calc_withdraw_one_coin(inAmount, i);
        return result;
    }

    /// @notice Convert USD amount to LP tokens
    function _usdToLp(uint256 inAmount) internal view returns (uint256) {
        return inAmount.mul(DEFAULT_DECIMALS_FACTOR).div(curvePool.get_virtual_price());
    }

    /// @notice Get absolute value
    function abs(int256 x) private pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }
}