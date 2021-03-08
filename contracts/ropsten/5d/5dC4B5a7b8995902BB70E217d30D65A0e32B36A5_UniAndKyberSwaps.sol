// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import {
    IERC20,
    SafeERC20
} from "../../vendor/openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "../../vendor/openzeppelin/contracts/math/SafeMath.sol";
import "../../dapps/krystal/burnHelper/IBurnGasHelper.sol";
import "../../interfaces/krystal/IKyberProxy.sol";
import "../../interfaces/dapps/Uniswap/IUniswapV2Router02.sol";
import "../../interfaces/krystal/IGasToken.sol";

abstract contract Utils {
    uint256 internal constant _MAX_AMOUNT = 2**256 - 1;
    uint256 internal constant _MAX_DECIMALS = 18;
    uint256 internal constant _MAX_QTY = (10**28);
    uint256 internal constant _PRECISION = (10**18);
    uint256 internal constant _MAX_RATE = (_PRECISION * 10**7);

    IERC20 internal constant _ETH_TOKEN_ADDRESS =
        IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function _calcDestAmount(
        IERC20 src,
        IERC20 dest,
        uint256 srcAmount,
        uint256 rate
    ) internal view returns (uint256) {
        return
            _calcDstQty(srcAmount, _getDecimals(src), _getDecimals(dest), rate);
    }

    function _calcDstQty(
        uint256 srcQty,
        uint256 srcDecimals,
        uint256 dstDecimals,
        uint256 rate
    ) internal pure returns (uint256) {
        require(srcQty <= _MAX_QTY, "srcQty > _MAX_QTY");
        require(rate <= _MAX_RATE, "rate > _MAX_RATE");

        if (dstDecimals >= srcDecimals) {
            require(
                (dstDecimals - srcDecimals) <= _MAX_DECIMALS,
                "dst - src > _MAX_DECIMALS"
            );
            return
                (srcQty * rate * (10**(dstDecimals - srcDecimals))) /
                _PRECISION;
        } else {
            require(
                (srcDecimals - dstDecimals) <= _MAX_DECIMALS,
                "src - dst > _MAX_DECIMALS"
            );
            return
                (srcQty * rate) /
                (_PRECISION * (10**(srcDecimals - dstDecimals)));
        }
    }

    function _calcRateFromQty(
        uint256 srcAmount,
        uint256 destAmount,
        uint256 srcDecimals,
        uint256 dstDecimals
    ) internal pure returns (uint256) {
        require(srcAmount <= _MAX_QTY, "srcAmount > _MAX_QTY");
        require(destAmount <= _MAX_QTY, "destAmount > _MAX_QTY");

        if (dstDecimals >= srcDecimals) {
            require(
                (dstDecimals - srcDecimals) <= _MAX_DECIMALS,
                "dst - src > _MAX_DECIMALS"
            );
            return ((destAmount * _PRECISION) /
                ((10**(dstDecimals - srcDecimals)) * srcAmount));
        } else {
            require(
                (srcDecimals - dstDecimals) <= _MAX_DECIMALS,
                "src - dst > _MAX_DECIMALS"
            );
            return ((destAmount *
                _PRECISION *
                (10**(srcDecimals - dstDecimals))) / srcAmount);
        }
    }

    function _getDecimals(IERC20 token)
        internal
        view
        returns (uint256 tokenDecimals)
    {
        // return token decimals if has constant value
        tokenDecimals = _getDecimalsConstant(token);
        if (tokenDecimals > 0) return tokenDecimals;

        // moreover, very possible that old tokens have decimals 0
        // these tokens will just have higher gas fees.
        return token.decimals();
    }

    function _getDecimalsConstant(IERC20 token)
        internal
        pure
        returns (uint256)
    {
        if (token == _ETH_TOKEN_ADDRESS) {
            return _MAX_DECIMALS;
        }

        return 0;
    }
}

contract UniAndKyberSwaps is Utils {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    mapping(address => bool) public uniRouters;
    IKyberProxy public immutable kyberProxy;
    IBurnGasHelper public immutable burnGasHelper;

    constructor(
        address _kyberProxy,
        address[] memory _uniRouters,
        address _burnGasHelper
    ) {
        kyberProxy = IKyberProxy(_kyberProxy);
        for (uint256 i = 0; i < _uniRouters.length; i++) {
            uniRouters[_uniRouters[i]] = true;
        }
        burnGasHelper = IBurnGasHelper(_burnGasHelper);
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    function swapKyber(
        IERC20 src,
        IERC20 dest,
        uint256 srcAmount,
        uint256 minConversionRate,
        address payable recipient,
        bytes calldata hint,
        bool useGasToken
    ) external payable returns (uint256 destAmount) {
        uint256 gasBefore = useGasToken ? gasleft() : 0;
        destAmount = _doKyberTrade(
            src,
            dest,
            srcAmount,
            minConversionRate,
            recipient,
            hint
        );
        uint256 numGasBurns = 0;
        // burn gas token if needed
        if (useGasToken) {
            numGasBurns = _burnGasTokensAfter(gasBefore);
        }
    }

    function swapUniswap(
        IUniswapV2Router02 router,
        uint256 srcAmount,
        uint256 minDestAmount,
        address[] calldata tradePath,
        address payable recipient,
        bool useGasToken
    ) external payable returns (uint256 destAmount) {
        require(uniRouters[address(router)], "router not supported");
        uint256 numGasBurns;
        {
            // prevent stack too deep
            uint256 gasBefore = useGasToken ? gasleft() : 0;
            destAmount = _swapUniswapInternal(
                router,
                srcAmount,
                minDestAmount,
                tradePath,
                recipient
            );
            if (useGasToken) {
                numGasBurns = _burnGasTokensAfter(gasBefore);
            }
        }
    }

    /// @dev get expected return and conversion rate if using Kyber
    function getExpectedReturnKyber(
        IERC20 src,
        IERC20 dest,
        uint256 srcAmount,
        bytes calldata hint
    ) external view returns (uint256 destAmount, uint256 expectedRate) {
        try
            kyberProxy.getExpectedRateAfterFee(src, dest, srcAmount, 0, hint)
        returns (uint256 rate) {
            expectedRate = rate;
        } catch {
            expectedRate = 0;
        }
        destAmount = _calcDestAmount(src, dest, srcAmount, expectedRate);
    }

    /// @dev get expected return and conversion rate if using a Uniswap router
    function getExpectedReturnUniswap(
        IUniswapV2Router02 router,
        uint256 srcAmount,
        address[] calldata tradePath
    ) external view returns (uint256 destAmount, uint256 expectedRate) {
        // in case router is not supported
        if (!uniRouters[address(router)]) {
            return (0, 0);
        }
        try router.getAmountsOut(srcAmount, tradePath) returns (
            uint256[] memory amounts
        ) {
            destAmount = amounts[tradePath.length - 1];
        } catch {
            destAmount = 0;
        }
        expectedRate = _calcRateFromQty(
            srcAmount,
            destAmount,
            _getDecimals(IERC20(tradePath[0])),
            _getDecimals(IERC20(tradePath[tradePath.length - 1]))
        );
    }

    function _doKyberTrade(
        IERC20 src,
        IERC20 dest,
        uint256 srcAmount,
        uint256 minConversionRate,
        address payable recipient,
        bytes memory hint
    ) internal returns (uint256 destAmount) {
        _validateAndPrepareSourceAmount(address(kyberProxy), src, srcAmount);
        uint256 callValue = src == _ETH_TOKEN_ADDRESS ? srcAmount : 0;
        destAmount = kyberProxy.tradeWithHintAndFee{value: callValue}(
            src,
            srcAmount,
            dest,
            recipient,
            _MAX_AMOUNT,
            minConversionRate,
            payable(0),
            0,
            hint
        );
    }

    function _swapUniswapInternal(
        IUniswapV2Router02 router,
        uint256 srcAmount,
        uint256 minDestAmount,
        address[] memory tradePath,
        address payable recipient
    ) internal returns (uint256 destAmount) {
        IERC20 src = IERC20(tradePath[0]);
        destAmount = _doUniswapTrade(
            router,
            src,
            srcAmount,
            minDestAmount,
            tradePath,
            recipient
        );
    }

    // solhint-disable-next-line function-max-lines
    function _doUniswapTrade(
        IUniswapV2Router02 router,
        IERC20 src,
        uint256 srcAmount,
        uint256 minDestAmount,
        address[] memory tradePath,
        address payable recipient
    ) internal returns (uint256 destAmount) {
        _validateAndPrepareSourceAmount(address(router), src, srcAmount);
        uint256 tradeLen = tradePath.length;
        IERC20 actualDest = IERC20(tradePath[tradeLen - 1]);
        {
            // convert eth -> weth address to trade on Uniswap
            if (tradePath[0] == address(_ETH_TOKEN_ADDRESS)) {
                tradePath[0] = router.WETH();
            }
            if (tradePath[tradeLen - 1] == address(_ETH_TOKEN_ADDRESS)) {
                tradePath[tradeLen - 1] = router.WETH();
            }
        }

        uint256[] memory amounts;
        if (src == _ETH_TOKEN_ADDRESS) {
            // swap eth -> token
            amounts = router.swapExactETHForTokens{value: srcAmount}(
                minDestAmount,
                tradePath,
                recipient,
                _MAX_AMOUNT
            );
        } else {
            if (actualDest == _ETH_TOKEN_ADDRESS) {
                // swap token -> eth
                amounts = router.swapExactTokensForETH(
                    srcAmount,
                    minDestAmount,
                    tradePath,
                    recipient,
                    _MAX_AMOUNT
                );
            } else {
                // swap token -> token
                amounts = router.swapExactTokensForTokens(
                    srcAmount,
                    minDestAmount,
                    tradePath,
                    recipient,
                    _MAX_AMOUNT
                );
            }
        }

        destAmount = amounts[amounts.length - 1];
    }

    function _validateAndPrepareSourceAmount(
        address protocol,
        IERC20 src,
        uint256 srcAmount
    ) internal {
        require(srcAmount > 0, "invalid src amount");
        if (src == _ETH_TOKEN_ADDRESS) {
            require(msg.value == srcAmount, "wrong msg value");
        } else {
            require(msg.value == 0, "wrong msg value");
            src.safeTransferFrom(msg.sender, address(this), srcAmount);
            src.safeApprove(protocol, srcAmount);
        }
    }

    function _burnGasTokensAfter(uint256 gasBefore)
        internal
        virtual
        returns (uint256 numGasBurns)
    {
        if (burnGasHelper == IBurnGasHelper(address(0))) return 0;
        IGasToken gasToken;
        uint256 gasAfter = gasleft();

        try
            burnGasHelper.getAmountGasTokensToBurn(
                gasBefore.sub(gasAfter),
                msg.data // forward all data
            )
        returns (uint256 _gasBurns, address _gasToken) {
            numGasBurns = _gasBurns;
            gasToken = IGasToken(_gasToken);
        } catch {
            numGasBurns = 0;
        }

        if (numGasBurns > 0 && gasToken != IGasToken(address(0))) {
            numGasBurns = gasToken.freeFromUpTo(msg.sender, numGasBurns);
        }
    }
}