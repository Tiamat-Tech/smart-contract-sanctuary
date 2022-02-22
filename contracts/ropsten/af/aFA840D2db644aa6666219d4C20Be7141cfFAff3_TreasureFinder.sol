// SPDX-License-Identifier: MIT
// P1 - P3: OK
pragma solidity ^0.8.0;
import "./BoringMath.sol";
import "./BoringERC20.sol";

import "./IUniswapV2ERC20.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";

import "./BoringOwnable.sol";

// TreasureFinder is TopDog's left hand and kinda a wizard. He can cook up Edan from pretty much anything!
// This contract handles "serving up" rewards for xPara, xOmega, tEdan holders by trading tokens collected from fees into the corresponding form.

// T1 - T4: OK
contract TreasureFinder is BoringOwnable {
    using BoringMath for uint256;
    using BoringERC20 for IERC20Uniswap;

    // V1 - V5: OK
    IUniswapV2Factory public immutable factory;
    //0xabcd...
    // V1 - V5: OK
    address public immutable buryEdan;
    //0xabcd..
    // V1 - V5: OK
    address public immutable buryOmega;
    //0xabcd..
    // V1 - V5: OK
    address public immutable buryPara;
    //0xabcd..
    // V1 - V5: OK
    address private immutable edan;
    //0xabcd...
    // V1 - V5: OK
    address private immutable omega;
    //0xabcd...
    // V1 - V5: OK
    address private immutable para;
    //0xabcd...
    // V1 - V5: OK
    address private immutable weth;
    //0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

    address public topCoinDestination;

    // V1 - V5: OK
    mapping(address => address) internal _bridges;

    // E1: OK
    event LogBridgeSet(address indexed token, address indexed bridge);
    // E1: OK
    event LogConvert(
        address indexed server,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 amountEDAN
    );
    event TopCoinDestination(address indexed user, address indexed destination);

    constructor (
        address _factory,
        address _swapRewardDistributor,
        address _buryEdan,
        address _buryOmega,
        address _buryPara,
        address _edan,
        address _omega,
        address _para,
        address _weth
    ) {
        require(address(_factory) != address(0), "_factory is a zero address");
        require(address(_edan) != address(0), "_edan is a zero address");
        require(address(_omega) != address(0), "_omega is a zero address");
        require(address(_para) != address(0), "_para is a zero address");
        require(address(_weth) != address(0), "_weth is a zero address");
        factory = IUniswapV2Factory(_factory);
        buryEdan = _buryEdan;
        buryOmega = _buryOmega;
        buryPara = _buryPara;
        edan = _edan;
        omega = _omega;
        para = _para;
        weth = _weth;
        topCoinDestination = _swapRewardDistributor;
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function bridgeFor(address token) public view returns (address bridge) {
        bridge = _bridges[token];
        if (bridge == address(0)) {
            bridge = weth;
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function setBridge(address token, address bridge) external onlyOwner {
        // Checks
        require(
            token != edan && token != weth && token != bridge,
            "TreasureFinder: Invalid bridge"
        );

        // Effects
        _bridges[token] = bridge;
        emit LogBridgeSet(token, bridge);
    }

    // M1 - M5: OK
    // C1 - C24: OK
    // C6: It's not a fool proof solution, but it prevents flash loans, so here it's ok to use tx.origin
    modifier onlyEOA() {
        // Try to make flash-loan exploit harder to do by only allowing externally owned addresses.
        require(msg.sender == tx.origin, "TreasureFinder: must use EOA");
        _;
    }

    // F1 - F10: OK
    // F3: _convert is separate to save gas by only checking the 'onlyEOA' modifier once in case of convertMultiple
    // F6: There is an exploit to add lots of EDAN to the bar, run convert, then remove the EDAN again.
    //     As the size of the BuryEdan has grown, this requires large amounts of funds and isn't super profitable anymore
    //     The onlyEOA modifier prevents this being done with a flash loan.
    // C1 - C24: OK
    function convert(address token0, address token1) external onlyEOA() {
        uint amountEDAN = _convert(token0, token1);
        buryTokens(amountEDAN);
    }

    // F1 - F10: OK, see convert
    // C1 - C24: OK
    // C3: Loop is under control of the caller
    function convertMultiple(
        address[] calldata token0,
        address[] calldata token1
    ) external onlyEOA() {
        // TODO: This can be optimized a fair bit, but this is safer and simpler for now
        uint256 len = token0.length;
        uint amountEDAN;
        for(uint256 i=0; i < len; i++) {
            amountEDAN = amountEDAN.add(_convert(token0[i], token1[i]));
        }
        buryTokens(amountEDAN);
    }

    function buryTokens(uint amountEDAN) internal {
        if(amountEDAN == 0) {
            return;
        }

        uint amountEDANtoBury = amountEDAN / 3;
        uint amountEDANtoSwap = amountEDAN.sub(amountEDANtoBury);

        uint ethToSwap = _swap(edan, weth, amountEDANtoSwap, address(this));
        uint ethForPara = ethToSwap / 2;
        uint ethForOmega = ethToSwap.sub(ethForPara);

        uint amountPARAtoBury = _swap(weth, para, ethForPara, para);
        uint amountOMEGAtoBury = _swap(weth, omega, ethForOmega, buryOmega);

        IERC20Uniswap(edan).safeTransfer(buryEdan, amountEDANtoBury);
    }

    // F1 - F10: OK
    // C1- C24: OK
    function _convert(address token0, address token1) internal returns(uint256) {
        // Interactions
        // S1 - S4: OK
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token0, token1));
        require(address(pair) != address(0), "TreasureFinder: Invalid pair");
        // balanceOf: S1 - S4: OK
        // transfer: X1 - X5: OK
        IERC20Uniswap(address(pair)).safeTransfer(
            address(pair),
            pair.balanceOf(address(this))
        );
        // X1 - X5: OK
        (uint256 amount0, uint256 amount1) = pair.burn(address(this));
        if (token0 != pair.token0()) {
            (amount0, amount1) = (amount1, amount0);
        }

        uint amountEDAN;
        if (!_convertTopCoins(token0, token1, amount0, amount1)) {
            // convert amount0, amount1 to EDAN
            amountEDAN = _convertStep(token0, token1, amount0, amount1);
            emit LogConvert(
                msg.sender,
                token0,
                token1,
                amount0,
                amount1,
                amountEDAN
            );
        }
        return amountEDAN;
    }

    function _convertTopCoins(
        address token0,
        address token1,
        uint amount0,
        uint amount1
    ) internal returns(bool) {

        bool isTop0 = factory.topCoins(token0);
        bool isTop1 = factory.topCoins(token1);

        if (isTop0 && isTop1) {
            IERC20Uniswap(token0).safeTransfer(topCoinDestination, amount0);
            IERC20Uniswap(token1).safeTransfer(topCoinDestination, amount1);
        }
        else if (isTop0) {
            IERC20Uniswap(token0).safeTransfer(topCoinDestination, _swap(token1, token0, amount1, address(this)).add(amount0));
        } else if (isTop1) {
            IERC20Uniswap(token1).safeTransfer(topCoinDestination, _swap(token0, token1, amount0, address(this)).add(amount1));
        } else {
            return false;
        }
        return true;
    }

    // F1 - F10: OK
    // C1 - C24: OK
    // All safeTransfer, _swap, _toEDAN, _convertStep: X1 - X5: OK
    function _convertStep(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal returns(uint256 edanOut) {
        // Interactions
        if (token0 == token1) {
            uint256 amount = amount0.add(amount1);
            if (token0 == edan) {
                edanOut = amount;
            } else if (token0 == weth) {
                edanOut = _toEDAN(weth, amount);
            } else {
                address bridge = bridgeFor(token0);
                amount = _swap(token0, bridge, amount, address(this));
                edanOut = _convertStep(bridge, bridge, amount, 0);
            }
        } else if (token0 == edan) {
            // eg. EDAN - ETH
            edanOut = _toEDAN(token1, amount1).add(amount0);
        } else if (token1 == edan) {
            // eg. USDT - EDAN
            edanOut = _toEDAN(token0, amount0).add(amount1);
        } else if (token0 == weth) {
            // eg. ETH - USDC
            edanOut = _toEDAN(
                weth,
                _swap(token1, weth, amount1, address(this)).add(amount0)
            );
        } else if (token1 == weth) {
            // eg. USDT - ETH
            edanOut = _toEDAN(
                weth,
                _swap(token0, weth, amount0, address(this)).add(amount1)
            );
        } else {
            // eg. MIC - USDT
            address bridge0 = bridgeFor(token0);
            address bridge1 = bridgeFor(token1);
            if (bridge0 == token1) {
                // eg. MIC - USDT - and bridgeFor(MIC) = USDT
                edanOut = _convertStep(
                    bridge0,
                    token1,
                    _swap(token0, bridge0, amount0, address(this)),
                    amount1
                );
            } else if (bridge1 == token0) {
                // eg. WBTC - DSD - and bridgeFor(DSD) = WBTC
                edanOut = _convertStep(
                    token0,
                    bridge1,
                    amount0,
                    _swap(token1, bridge1, amount1, address(this))
                );
            } else {
                // eg. USDT - DSD - and bridgeFor(DSD) = WBTC
                edanOut = _convertStep(
                    bridge0,
                    bridge1,
                    _swap(token0, bridge0, amount0, address(this)),
                    _swap(token1, bridge1, amount1, address(this))
                );
            }
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    // All safeTransfer, swap: X1 - X5: OK
    function _swap(address fromToken, address toToken, uint256 amountIn, address to) internal returns (uint256 amountOut) {

        if(amountIn == 0) {
            return 0;
        }
        // Checks
        // X1 - X5: OK
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(fromToken, toToken));
        require(address(pair) != address(0), "TreasureFinder: Cannot convert");

        // Interactions
        // X1 - X5: OK
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(uint(1000).sub(pair.totalFee()));
        if (fromToken == pair.token0()) {
            amountOut = amountInWithFee.mul(reserve1) / reserve0.mul(1000).add(amountInWithFee);
            IERC20Uniswap(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
            // TODO: Add maximum slippage?
        } else {
            amountOut = amountInWithFee.mul(reserve0) / reserve1.mul(1000).add(amountInWithFee);
            IERC20Uniswap(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
            // TODO: Add maximum slippage?
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function _toEDAN(address token, uint256 amountIn) internal returns(uint256 amountOut) {
        // X1 - X5: OK
        amountOut = _swap(token, edan, amountIn, address(this));
    }

    function setTopCinDestination(address _destination) external onlyOwner {
        topCoinDestination = _destination;
        emit TopCoinDestination(msg.sender, _destination);
    }
}