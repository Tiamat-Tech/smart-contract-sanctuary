// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
// import 'hardhat/console.sol';
import './interfaces/UniswapRouterV2.sol';
import './interfaces/BakeryRouterV2.sol';
import './interfaces/DODOV2Proxy.sol';
import './interfaces/VyperSwap.sol';
import './interfaces/VyperUnderlyingSwap.sol';
import './interfaces/DoppleSwap.sol';

contract ArkenDex {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant DEADLINE = 2**256 - 1;
    IERC20 constant ETHER_ERC20 =
        IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    enum RouterInterface {
        UNISWAP,
        BAKERY,
        VYPER,
        VYPER_UNDERLYING,
        DOPPLE,
        DODO_V2,
        DODO_V1
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    struct TradeRoute {
        address[] paths;
        address[] dodoPairs;
        uint256 dodoDirection;
        address dexAddr;
        RouterInterface dexInterface;
        uint256 part;
    }

    struct MultiSwapDesctiption {
        IERC20 srcToken;
        IERC20 dstToken;
        TradeRoute[] routes;
        uint256 amountIn;
        uint256 amountOutMin;
        address payable to;
    }

    event Swapped(
        address srcToken,
        address dstToken,
        uint256 amountIn,
        uint256 returnAmount
    );

    event UpdateVyper(address dexAddr, address[] tokens);

    event Received(address sender, uint256 amount);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    address public ownerAddress;
    address payable public feeWalletAddress;
    address dodoApproveAddress;
    IERC20 wrapperEtherERC20;
    mapping(address => mapping(address => int128)) vyperCoinsMap;

    modifier onlyOwner() {
        require(msg.sender == ownerAddress, 'Not owner');
        _;
    }

    struct VyperConstructor {
        address[] dexAddress;
        address[][] tokenAddress;
    }

    constructor(
        address payable _feeWalletAddress,
        address _owner,
        IERC20 _wrappedEther,
        address _dodoApproveAddress,
        VyperConstructor memory _vyperParams
    ) {
        ownerAddress = _owner;
        wrapperEtherERC20 = _wrappedEther;
        feeWalletAddress = _feeWalletAddress;
        dodoApproveAddress = _dodoApproveAddress;
        _initializeVyper(_vyperParams);
    }

    function _initializeVyper(VyperConstructor memory params) private {
        address[] memory dexAddrs = params.dexAddress;
        address[][] memory tokenAddrs = params.tokenAddress;
        require(
            dexAddrs.length == tokenAddrs.length,
            'vyper params dexAddress and tokenAddress and tokenIndex has to be the same length'
        );
        for (uint32 i = 0; i < dexAddrs.length; i++) {
            for (int128 j = 0; uint128(j) < tokenAddrs[i].length; j++) {
                vyperCoinsMap[dexAddrs[i]][tokenAddrs[i][uint128(j)]] = j;
            }
        }
    }

    /**
     * External Functions
     */
    function updateVyper(address dexAddress, address[] calldata tokens)
        external
        onlyOwner
    {
        for (int128 j = 0; uint128(j) < tokens.length; j++) {
            vyperCoinsMap[dexAddress][tokens[uint128(j)]] = j;
        }
        emit UpdateVyper(dexAddress, tokens);
    }

    function multiTrade(MultiSwapDesctiption memory desc)
        external
        payable
        returns (uint256 returnAmount, uint256 blockNumber)
    {
        IERC20 dstToken = desc.dstToken;
        IERC20 srcToken = desc.srcToken;
        (returnAmount, blockNumber) = _trade(desc);
        if (ETHER_ERC20 == desc.dstToken) {
            (bool sent, ) = desc.to.call{value: returnAmount}('');
            require(sent, 'Failed to send Ether');
        } else {
            dstToken.safeTransfer(msg.sender, returnAmount);
        }
        emit Swapped(
            address(srcToken),
            address(dstToken),
            desc.amountIn,
            returnAmount
        );
    }

    function testTransfer(MultiSwapDesctiption memory desc)
        external
        payable
        returns (uint256 returnAmount, uint256 blockNumber)
    {
        IERC20 dstToken = desc.dstToken;
        (returnAmount, blockNumber) = _trade(desc);
        uint256 beforeAmount = dstToken.balanceOf(msg.sender);
        dstToken.transfer(msg.sender, returnAmount);
        uint256 afterAmount = dstToken.balanceOf(msg.sender);
        uint256 got = afterAmount - beforeAmount;
        require(got == returnAmount, 'ArkenTester: Has Tax');
    }

    function getVyperData(address dexAddress, address token)
        external
        view
        returns (int128)
    {
        return vyperCoinsMap[dexAddress][token];
    }

    /**
     * Trade Logic
     */

    function _trade(MultiSwapDesctiption memory desc)
        internal
        returns (uint256 returnAmount, uint256 blockNumber)
    {
        require(desc.amountIn > 0, 'Amount-in needs to be more than zero');
        blockNumber = block.number;

        IERC20 srcToken = desc.srcToken;

        if (ETHER_ERC20 == desc.srcToken) {
            require(msg.value == desc.amountIn, 'Value not match amountIn');
        } else {
            uint256 allowance = srcToken.allowance(msg.sender, address(this));
            require(allowance >= desc.amountIn, 'Allowance not enough');
            srcToken.safeTransferFrom(msg.sender, address(this), desc.amountIn);
        }

        TradeRoute[] memory routes = desc.routes;
        uint256 srcTokenAmount;

        for (uint256 i = 0; i < routes.length; i++) {
            TradeRoute memory route = routes[i];
            IERC20 startToken = ERC20(route.paths[0]);
            IERC20 endToken = ERC20(route.paths[route.paths.length - 1]);
            if (ETHER_ERC20 == startToken) {
                srcTokenAmount = address(this).balance;
            } else {
                srcTokenAmount = startToken.balanceOf(address(this));
            }
            uint256 inputAmount = srcTokenAmount.mul(route.part).div(100000000); // 1% = 10^6
            require(
                route.part <= 100000000,
                'Route percentage can not exceed 100000000'
            );
            // uint256[] memory amounts;
            if (route.dexInterface == RouterInterface.BAKERY) {
                // amounts =
                _tradeIBakery(
                    startToken,
                    endToken,
                    inputAmount,
                    0,
                    route.paths,
                    address(this),
                    route.dexAddr
                );
            } else if (route.dexInterface == RouterInterface.VYPER) {
                // amounts =
                _tradeVyper(
                    startToken,
                    endToken,
                    inputAmount,
                    0,
                    route.dexAddr
                );
            } else if (route.dexInterface == RouterInterface.VYPER_UNDERLYING) {
                // amounts =
                _tradeVyperUnderlying(
                    startToken,
                    endToken,
                    inputAmount,
                    0,
                    route.dexAddr
                );
            } else if (route.dexInterface == RouterInterface.DOPPLE) {
                // amounts =
                _tradeDopple(
                    startToken,
                    endToken,
                    inputAmount,
                    0,
                    route.dexAddr
                );
            } else if (route.dexInterface == RouterInterface.DODO_V2) {
                // DODO doesn't allow zero min amount
                // amount =
                _tradeIDODOV2(
                    startToken,
                    endToken,
                    inputAmount,
                    1,
                    route.dodoPairs,
                    route.dodoDirection,
                    route.dexAddr
                );
            } else if (route.dexInterface == RouterInterface.DODO_V1) {
                // DODO doesn't allow zero min amount
                // amount =
                _tradeIDODOV1(
                    startToken,
                    endToken,
                    inputAmount,
                    1,
                    route.dodoPairs,
                    route.dodoDirection,
                    route.dexAddr
                );
            } else {
                // amounts =
                _tradeIUniswap(
                    startToken,
                    endToken,
                    inputAmount,
                    0,
                    route.paths,
                    address(this),
                    route.dexAddr
                );
            }
            // for (uint256 idx = 0; idx < amounts.length; idx++) {
            //     console.log('\tamount[%d]: %d', idx, amounts[idx]);
            // }
        }

        if (ETHER_ERC20 == desc.dstToken) {
            returnAmount = address(this).balance;
        } else {
            returnAmount = desc.dstToken.balanceOf(address(this));
        }

        returnAmount = _collectFee(returnAmount, desc.dstToken);
        // console.log(
        //     'after fee: %d ,, out min: %d',
        //     returnAmount,
        //     desc.amountOutMin
        // );
        require(
            returnAmount >= desc.amountOutMin,
            'Return amount is not enough'
        );
    }

    /**
     * Internal Functions
     */

    function _collectFee(uint256 amount, IERC20 token)
        private
        returns (
            uint256 // remaining amount to swap
        )
    {
        uint256 fee = amount.div(1000); // 0.1%
        // console.log('fee: %s from %s on %s', fee, amount, address(token));
        require(fee < amount, 'Fee exceeds amount');
        if (ETHER_ERC20 == token) {
            feeWalletAddress.transfer(fee);
        } else {
            token.safeTransfer(feeWalletAddress, fee);
        }
        return amount.sub(fee);
    }

    function _tradeIUniswap(
        IERC20 _src,
        IERC20 _dest,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address[] memory paths,
        address to,
        address dexAddr
    ) private returns (uint256[] memory amounts) {
        IUniswapV2Router uniRouter = IUniswapV2Router(dexAddr);
        if (_src == ETHER_ERC20) {
            // ETH => TOKEN
            if (paths[0] == address(ETHER_ERC20)) {
                paths[0] = address(wrapperEtherERC20);
            }
            amounts = uniRouter.swapExactETHForTokens{value: inputAmount}(
                minOutputAmount,
                paths,
                to,
                DEADLINE
            );
        } else if (_dest == ETHER_ERC20) {
            // TOKEN => ETH
            if (paths[paths.length - 1] == address(ETHER_ERC20)) {
                paths[paths.length - 1] = address(wrapperEtherERC20);
            }
            _src.safeApprove(dexAddr, inputAmount);
            amounts = uniRouter.swapExactTokensForETH(
                inputAmount,
                minOutputAmount,
                paths,
                to,
                DEADLINE
            );
        } else {
            // TOKEN => TOKEN
            _src.safeApprove(dexAddr, inputAmount);
            amounts = uniRouter.swapExactTokensForTokens(
                inputAmount,
                minOutputAmount,
                paths,
                to,
                DEADLINE
            );
        }
    }

    function _tradeIDODOV2(
        IERC20 _src,
        IERC20 _dest,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address[] memory dodoPairs,
        uint256 direction,
        address dexAddr
    ) private returns (uint256 amount) {
        IDODOV2Proxy dodoProxy = IDODOV2Proxy(dexAddr);
        if (_src == ETHER_ERC20) {
            // ETH => TOKEN
            amount = dodoProxy.dodoSwapV2ETHToToken{value: inputAmount}(
                address(_dest),
                minOutputAmount,
                dodoPairs,
                direction,
                false,
                DEADLINE
            );
        } else if (_dest == ETHER_ERC20) {
            // TOKEN => ETH
            _src.safeApprove(dodoApproveAddress, inputAmount);
            amount = dodoProxy.dodoSwapV2TokenToETH(
                address(_src),
                inputAmount,
                minOutputAmount,
                dodoPairs,
                direction,
                false,
                DEADLINE
            );
        } else {
            // TOKEN => TOKEN
            _src.safeApprove(dodoApproveAddress, inputAmount);
            amount = dodoProxy.dodoSwapV2TokenToToken(
                address(_src),
                address(_dest),
                inputAmount,
                minOutputAmount,
                dodoPairs,
                direction,
                false,
                DEADLINE
            );
        }
    }

    function _tradeIDODOV1(
        IERC20 _src,
        IERC20 _dest,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address[] memory dodoPairs,
        uint256 direction,
        address dexAddr
    ) private returns (uint256 amount) {
        IDODOV2Proxy dodoProxy = IDODOV2Proxy(dexAddr);
        IERC20 src = _src;
        IERC20 dest = _dest;
        if (_src != ETHER_ERC20) {
            _src.safeApprove(dodoApproveAddress, inputAmount);
        }
        // console.log('dodo v1 addr: %s , %s', address(src), address(dest));
        // console.log('dodo v1 amt: %d , %d', inputAmount, minOutputAmount);
        amount = dodoProxy.dodoSwapV1(
            address(src),
            address(dest),
            inputAmount,
            minOutputAmount,
            dodoPairs,
            direction,
            false,
            DEADLINE
        );
        // console.log('dodo v1 amount: %d', amount);
    }

    function _tradeIBakery(
        IERC20 _src,
        IERC20 _dest,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address[] memory paths,
        address to,
        address dexAddr
    ) private returns (uint256[] memory amounts) {
        IBakeryV2Router bakeryRouter = IBakeryV2Router(dexAddr);
        if (_src == ETHER_ERC20) {
            // ETH => TOKEN
            if (paths[0] == address(ETHER_ERC20)) {
                paths[0] = address(wrapperEtherERC20);
            }
            amounts = bakeryRouter.swapExactBNBForTokens{value: inputAmount}(
                minOutputAmount,
                paths,
                to,
                DEADLINE
            );
        } else if (_dest == ETHER_ERC20) {
            // TOKEN => ETH
            if (paths[paths.length - 1] == address(ETHER_ERC20)) {
                paths[paths.length - 1] = address(wrapperEtherERC20);
            }
            _src.safeApprove(dexAddr, inputAmount);
            amounts = bakeryRouter.swapExactTokensForBNB(
                inputAmount,
                minOutputAmount,
                paths,
                to,
                DEADLINE
            );
        } else {
            // TOKEN => TOKEN
            _src.safeApprove(dexAddr, inputAmount);
            amounts = bakeryRouter.swapExactTokensForTokens(
                inputAmount,
                minOutputAmount,
                paths,
                to,
                DEADLINE
            );
        }
    }

    function _tradeVyper(
        IERC20 _src,
        IERC20 _dest,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address dexAddr
    ) private {
        IVyperSwap vyperSwap = IVyperSwap(dexAddr);
        _src.safeApprove(dexAddr, inputAmount);
        int128 tokenIndexFrom = vyperCoinsMap[dexAddr][address(_src)];
        // console.log('tokenIndexFrom: %d', uint128(tokenIndexFrom));
        int128 tokenIndexTo = vyperCoinsMap[dexAddr][address(_dest)];
        // console.log('tokenIndexTo: %d', uint128(tokenIndexTo));
        vyperSwap.exchange(
            tokenIndexFrom,
            tokenIndexTo,
            inputAmount,
            minOutputAmount
        );
    }

    function _tradeVyperUnderlying(
        IERC20 _src,
        IERC20 _dest,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address dexAddr
    ) private {
        IVyperUnderlyingSwap vyperSwap = IVyperUnderlyingSwap(dexAddr);
        _src.safeApprove(dexAddr, inputAmount);
        int128 tokenIndexFrom = vyperCoinsMap[dexAddr][address(_src)];
        // console.log('tokenIndexFrom: %d', uint128(tokenIndexFrom));
        int128 tokenIndexTo = vyperCoinsMap[dexAddr][address(_dest)];
        // console.log('tokenIndexTo: %d', uint128(tokenIndexTo));
        vyperSwap.exchange_underlying(
            tokenIndexFrom,
            tokenIndexTo,
            inputAmount,
            minOutputAmount
        );
    }

    function _tradeDopple(
        IERC20 _src,
        IERC20 _dest,
        uint256 inputAmount,
        uint256 minOutputAmount,
        address dexAddr
    ) private returns (uint256 amount) {
        IDoppleSwap doppleSwap = IDoppleSwap(dexAddr);
        _src.safeApprove(dexAddr, inputAmount);
        // console.log('getTokenIndex: %s %s', address(_src), address(_dest));
        uint8 tokenIndexFrom = doppleSwap.getTokenIndex(address(_src));
        // console.log('tokenIndexFrom: %d', uint128(tokenIndexFrom));
        uint8 tokenIndexTo = doppleSwap.getTokenIndex(address(_dest));
        // console.log('tokenIndexTo: %d', uint128(tokenIndexTo));
        amount = doppleSwap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            inputAmount,
            minOutputAmount,
            DEADLINE
        );
    }
}