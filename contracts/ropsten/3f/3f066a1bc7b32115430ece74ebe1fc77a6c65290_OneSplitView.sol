// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interface/IUniswapFactory.sol";
import "./interface/IUniswapV2Factory.sol";
import "./interface/IHandlerReserve.sol";
import "./interface/IEthHandler.sol";
import "./interface/IBridge.sol";
import "./IOneSplit.sol";
import "./UniversalERC20.sol";
import "./interface/IWETH.sol";
import "./libraries/TransferHelper.sol";

import "hardhat/console.sol";

abstract contract IOneSplitView is IOneSplitConsts {
    function getExpectedReturn(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) public view virtual returns (uint256 returnAmount, uint256[] memory distribution);

    function getExpectedReturnWithGas(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 destTokenEthPriceTimesGasPrice
    )
        public
        view
        virtual
        returns (
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        );
}

library DisableFlags {
    function check(uint256 flags, uint256 flag) internal pure returns (bool) {
        return (flags & flag) != 0;
    }
}

contract OneSplitRoot {
    using SafeMathUpgradeable for uint256;
    using DisableFlags for uint256;

    using UniversalERC20 for IERC20Upgradeable;
    using UniversalERC20 for IWETH;
    using UniswapV2ExchangeLib for IUniswapV2Exchange;

    uint256 internal constant DEXES_COUNT = 5;
    IERC20Upgradeable internal constant ZERO_ADDRESS = IERC20Upgradeable(0x0000000000000000000000000000000000000000);

    IERC20Upgradeable internal constant ETH_ADDRESS = IERC20Upgradeable(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IWETH internal constant weth = IWETH(0xc778417E063141139Fce010982780140Aa0cD5Ab);

    IERC20Upgradeable internal constant MATIC_ADDRESS = IERC20Upgradeable(0x0000000000000000000000000000000000001010);
    IWETH internal constant wmatic = IWETH(0x6373c962DCFfc21465973150993E19F56d8640a4);

    IERC20Upgradeable internal constant BNB_ADDRESS = IERC20Upgradeable(0x0000000000000000000000000000000000000000);
    IWETH internal constant wbnb = IWETH(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    IUniswapFactory internal constant uniswapFactory = IUniswapFactory(0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95);
    IUniswapV2Factory internal constant uniswapV2 = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Factory internal constant dfynExchange = IUniswapV2Factory(0x22e18D791EeE1EE7Eda4c7d6a9D435A8CA10Cf78);
    IUniswapV2Factory internal constant pancakeSwap = IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    IUniswapV2Factory internal constant quickSwap = IUniswapV2Factory(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);

    int256 internal constant VERY_NEGATIVE_VALUE = -1e72;
    address internal constant skimAddress = 0x01291560CeA94286aa6F230ae8C074b08F70B7A6;

    function _findBestDistribution(
        uint256 s, // parts
        int256[][] memory amounts // exchangesReturns
    ) internal pure returns (int256 returnAmount, uint256[] memory distribution) {
        uint256 n = amounts.length;

        int256[][] memory answer = new int256[][](n); // int[n][s+1]
        uint256[][] memory parent = new uint256[][](n); // int[n][s+1]

        for (uint256 i = 0; i < n; i++) {
            answer[i] = new int256[](s + 1);
            parent[i] = new uint256[](s + 1);
        }

        for (uint256 j = 0; j <= s; j++) {
            answer[0][j] = amounts[0][j];
            for (uint256 i = 1; i < n; i++) {
                answer[i][j] = -1e72;
            }
            parent[0][j] = 0;
        }

        for (uint256 i = 1; i < n; i++) {
            for (uint256 j = 0; j <= s; j++) {
                answer[i][j] = answer[i - 1][j];
                parent[i][j] = j;

                for (uint256 k = 1; k <= j; k++) {
                    if (answer[i - 1][j - k] + amounts[i][k] > answer[i][j]) {
                        answer[i][j] = answer[i - 1][j - k] + amounts[i][k];
                        parent[i][j] = j - k;
                    }
                }
            }
        }

        distribution = new uint256[](DEXES_COUNT);

        uint256 partsLeft = s;
        for (uint256 curExchange = n - 1; partsLeft > 0; curExchange--) {
            distribution[curExchange] = partsLeft - parent[curExchange][partsLeft];
            partsLeft = parent[curExchange][partsLeft];
        }

        returnAmount = (answer[n - 1][s] == VERY_NEGATIVE_VALUE) ? int256(0) : answer[n - 1][s];
    }

    function _linearInterpolation(uint256 value, uint256 parts) internal pure returns (uint256[] memory rets) {
        rets = new uint256[](parts);
        for (uint256 i = 0; i < parts; i++) {
            rets[i] = value.mul(i + 1).div(parts);
        }
    }

    function _tokensEqual(IERC20Upgradeable tokenA, IERC20Upgradeable tokenB) internal pure returns (bool) {
        return ((tokenA.isETH() && tokenB.isETH()) || tokenA == tokenB);
    }
}

contract OneSplitView is Initializable, IOneSplitView, OneSplitRoot, UUPSUpgradeable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;
    using DisableFlags for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using UniversalERC20 for IERC20Upgradeable;

    function initialize() public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function getExpectedReturn(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags // See constants in IOneSplit.sol
    ) public view override returns (uint256 returnAmount, uint256[] memory distribution) {
        (returnAmount, , distribution) = getExpectedReturnWithGas(fromToken, destToken, amount, parts, flags, 0);
    }

    function getExpectedReturnWithGas(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags, // See constants in IOneSplit.sol
        uint256 destTokenEthPriceTimesGasPrice
    )
        public
        view
        override
        returns (
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        distribution = new uint256[](DEXES_COUNT);

        if (fromToken == destToken) {
            return (amount, 0, distribution);
        }

        function(IERC20Upgradeable, IERC20Upgradeable, uint256, uint256, uint256)
            view
            returns (uint256[] memory, uint256)[DEXES_COUNT]
            memory reserves = _getAllReserves(flags);

        int256[][] memory matrix = new int256[][](DEXES_COUNT);
        uint256[DEXES_COUNT] memory gases;
        bool atLeastOnePositive = false;
        for (uint256 i = 0; i < DEXES_COUNT; i++) {
            uint256[] memory rets;
            (rets, gases[i]) = reserves[i](fromToken, destToken, amount, parts, flags);

            // Prepend zero and sub gas
            int256 gas = int256(gases[i].mul(destTokenEthPriceTimesGasPrice).div(1e18));
            matrix[i] = new int256[](parts + 1);
            for (uint256 j = 0; j < rets.length; j++) {
                matrix[i][j + 1] = int256(rets[j]) - gas;
                atLeastOnePositive = atLeastOnePositive || (matrix[i][j + 1] > 0);
            }
        }

        if (!atLeastOnePositive) {
            for (uint256 i = 0; i < DEXES_COUNT; i++) {
                for (uint256 j = 1; j < parts + 1; j++) {
                    if (matrix[i][j] == 0) {
                        matrix[i][j] = VERY_NEGATIVE_VALUE;
                    }
                }
            }
        }

        (, distribution) = _findBestDistribution(parts, matrix);

        (returnAmount, estimateGasAmount) = _getReturnAndGasByDistribution(
            Args({
                fromToken: fromToken,
                destToken: destToken,
                amount: amount,
                parts: parts,
                flags: flags,
                destTokenEthPriceTimesGasPrice: destTokenEthPriceTimesGasPrice,
                distribution: distribution,
                matrix: matrix,
                gases: gases,
                reserves: reserves
            })
        );
        return (returnAmount, estimateGasAmount, distribution);
    }

    struct Args {
        IERC20Upgradeable fromToken;
        IERC20Upgradeable destToken;
        uint256 amount;
        uint256 parts;
        uint256 flags;
        uint256 destTokenEthPriceTimesGasPrice;
        uint256[] distribution;
        int256[][] matrix;
        uint256[DEXES_COUNT] gases;
        function(IERC20Upgradeable, IERC20Upgradeable, uint256, uint256, uint256)
            view
            returns (uint256[] memory, uint256)[DEXES_COUNT] reserves;
    }

    function _getReturnAndGasByDistribution(Args memory args)
        internal
        view
        returns (uint256 returnAmount, uint256 estimateGasAmount)
    {
        bool[DEXES_COUNT] memory exact = [
            true, // "Uniswap",
            true, // "Uniswap V2",
            true, // DFYN
            true, // pancake swap
            true // quickswap
        ];

        for (uint256 i = 0; i < DEXES_COUNT; i++) {
            if (args.distribution[i] > 0) {
                if (
                    args.distribution[i] == args.parts || exact[i] || args.flags.check(FLAG_DISABLE_SPLIT_RECALCULATION)
                ) {
                    estimateGasAmount = estimateGasAmount.add(args.gases[i]);
                    int256 value = args.matrix[i][args.distribution[i]];
                    returnAmount = returnAmount.add(
                        uint256(
                            (value == VERY_NEGATIVE_VALUE ? int256(0) : value) +
                                int256(args.gases[i].mul(args.destTokenEthPriceTimesGasPrice).div(1e18))
                        )
                    );
                } else {
                    (uint256[] memory rets, uint256 gas) = args.reserves[i](
                        args.fromToken,
                        args.destToken,
                        args.amount.mul(args.distribution[i]).div(args.parts),
                        1,
                        args.flags
                    );
                    estimateGasAmount = estimateGasAmount.add(gas);
                    returnAmount = returnAmount.add(rets[0]);
                }
            }
        }
    }

    function _getAllReserves(uint256 flags)
        internal
        pure
        returns (
            function(IERC20Upgradeable, IERC20Upgradeable, uint256, uint256, uint256)
                view
                returns (uint256[] memory, uint256)[DEXES_COUNT]
                memory
        )
    {
        bool invert = flags.check(FLAG_DISABLE_ALL_SPLIT_SOURCES);
        return [
            invert != flags.check(FLAG_DISABLE_UNISWAP_ALL | FLAG_DISABLE_UNISWAP)
                ? _calculateNoReturn
                : calculateUniswap,
            invert != flags.check(FLAG_DISABLE_UNISWAP_V2_ALL | FLAG_DISABLE_UNISWAP_V2)
                ? _calculateNoReturn
                : calculateUniswapV2,
            invert != flags.check(FLAG_DISABLE_DFYN) ? _calculateNoReturn : calculateDfyn,
            invert != flags.check(FLAG_DISABLE_PANCAKESWAP) ? _calculateNoReturn : calculatePancakeSwap,
            invert != flags.check(FLAG_DISABLE_QUICKSWAP) ? _calculateNoReturn : calculateQuickSwap
        ];
    }

    function _calculateUniswapFormula(
        uint256 fromBalance,
        uint256 toBalance,
        uint256 amount
    ) internal pure returns (uint256) {
        if (amount == 0) {
            return 0;
        }
        return amount.mul(toBalance).mul(997).div(fromBalance.mul(1000).add(amount.mul(997)));
    }

    function _calculateUniswap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256[] memory amounts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        rets = amounts;

        if (!fromToken.isETH()) {
            IUniswapExchange fromExchange = uniswapFactory.getExchange(fromToken);
            if (fromExchange == IUniswapExchange(address(0))) {
                return (new uint256[](rets.length), 0);
            }

            uint256 fromTokenBalance = fromToken.universalBalanceOf(address(fromExchange));
            uint256 fromEtherBalance = address(fromExchange).balance;

            for (uint256 i = 0; i < rets.length; i++) {
                rets[i] = _calculateUniswapFormula(fromTokenBalance, fromEtherBalance, rets[i]);
            }
        }

        if (!destToken.isETH()) {
            IUniswapExchange toExchange = uniswapFactory.getExchange(destToken);
            if (toExchange == IUniswapExchange(address(0))) {
                return (new uint256[](rets.length), 0);
            }

            uint256 toEtherBalance = address(toExchange).balance;
            uint256 toTokenBalance = destToken.universalBalanceOf(address(toExchange));

            for (uint256 i = 0; i < rets.length; i++) {
                rets[i] = _calculateUniswapFormula(toEtherBalance, toTokenBalance, rets[i]);
            }
        }

        return (rets, fromToken.isETH() || destToken.isETH() ? 60_000 : 100_000);
    }

    function calculateUniswap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        return _calculateUniswap(fromToken, destToken, _linearInterpolation(amount, parts), flags);
    }

    function calculateDfyn(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        return _calculateDfynswap(fromToken, destToken, _linearInterpolation(amount, parts), flags);
    }

    function calculatePancakeSwap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        return _calculatePancakeswap(fromToken, destToken, _linearInterpolation(amount, parts), flags);
    }

    function calculateQuickSwap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        return _calculateQuickswap(fromToken, destToken, _linearInterpolation(amount, parts), flags);
    }

    function calculateUniswapV2(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        return _calculateUniswapV2(fromToken, destToken, _linearInterpolation(amount, parts), flags);
    }

    function _calculateDfynswap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256[] memory amounts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        rets = new uint256[](amounts.length);

        IERC20Upgradeable fromTokenReal = fromToken.isETH() ? wmatic : fromToken;
        IERC20Upgradeable destTokenReal = destToken.isETH() ? wmatic : destToken;
        IUniswapV2Exchange exchange = dfynExchange.getPair(fromTokenReal, destTokenReal);
        if (exchange != IUniswapV2Exchange(address(0))) {
            uint256 fromTokenBalance = fromTokenReal.universalBalanceOf(address(exchange));
            uint256 destTokenBalance = destTokenReal.universalBalanceOf(address(exchange));
            for (uint256 i = 0; i < amounts.length; i++) {
                rets[i] = _calculateUniswapFormula(fromTokenBalance, destTokenBalance, amounts[i]);
            }
            return (rets, 50_000);
        }
    }

    function _calculateQuickswap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256[] memory amounts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        rets = new uint256[](amounts.length);

        IERC20Upgradeable fromTokenReal = fromToken.isETH() ? wmatic : fromToken;
        IERC20Upgradeable destTokenReal = destToken.isETH() ? wmatic : destToken;
        IUniswapV2Exchange exchange = quickSwap.getPair(fromTokenReal, destTokenReal);
        if (exchange != IUniswapV2Exchange(address(0))) {
            uint256 fromTokenBalance = fromTokenReal.universalBalanceOf(address(exchange));
            uint256 destTokenBalance = destTokenReal.universalBalanceOf(address(exchange));
            for (uint256 i = 0; i < amounts.length; i++) {
                rets[i] = _calculateUniswapFormula(fromTokenBalance, destTokenBalance, amounts[i]);
            }
            return (rets, 50_000);
        }
    }

    function _calculatePancakeswap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256[] memory amounts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        rets = new uint256[](amounts.length);

        IERC20Upgradeable fromTokenReal = fromToken.isETH() ? wbnb : fromToken;
        IERC20Upgradeable destTokenReal = destToken.isETH() ? wbnb : destToken;
        IUniswapV2Exchange exchange = pancakeSwap.getPair(fromTokenReal, destTokenReal);
        if (exchange != IUniswapV2Exchange(address(0))) {
            uint256 fromTokenBalance = fromTokenReal.universalBalanceOf(address(exchange));
            uint256 destTokenBalance = destTokenReal.universalBalanceOf(address(exchange));
            for (uint256 i = 0; i < amounts.length; i++) {
                rets[i] = _calculateUniswapFormula(fromTokenBalance, destTokenBalance, amounts[i]);
            }
            return (rets, 50_000);
        }
    }

    function _calculateUniswapV2(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256[] memory amounts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        rets = new uint256[](amounts.length);

        IERC20Upgradeable fromTokenReal = fromToken.isETH() ? weth : fromToken;
        IERC20Upgradeable destTokenReal = destToken.isETH() ? weth : destToken;
        IUniswapV2Exchange exchange = uniswapV2.getPair(fromTokenReal, destTokenReal);
        if (exchange != IUniswapV2Exchange(address(0))) {
            uint256 fromTokenBalance = fromTokenReal.universalBalanceOf(address(exchange));
            uint256 destTokenBalance = destTokenReal.universalBalanceOf(address(exchange));
            for (uint256 i = 0; i < amounts.length; i++) {
                rets[i] = _calculateUniswapFormula(fromTokenBalance, destTokenBalance, amounts[i]);
            }
            return (rets, 50_000);
        }
    }

    function _calculateNoReturn(
        IERC20Upgradeable, /*fromToken*/
        IERC20Upgradeable, /*destToken*/
        uint256, /*amount*/
        uint256 parts,
        uint256 /*flags*/
    ) internal view returns (uint256[] memory rets, uint256 gas) {
        this;
        return (new uint256[](parts), 0);
    }
}

contract OneSplit is Initializable, IOneSplit, OneSplitRoot, UUPSUpgradeable, AccessControlUpgradeable {
    using UniversalERC20 for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using DisableFlags for uint256;
    using UniswapV2ExchangeLib for IUniswapV2Exchange;
    IOneSplitView public oneSplitView;
    address public handlerAddress;
    IHandlerReserve public reserveInstance;
    IBridge public bridgeInstance;
    IEthHandler private _ethHandler;

    //Alternative for constructor in upgradable contract

    function initialize(
        IOneSplitView _oneSplitView,
        address _handlerAddress,
        address _reserveAddress,
        address _bridgeAddress
    ) public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        oneSplitView = _oneSplitView;
        handlerAddress = _handlerAddress;
        reserveInstance = IHandlerReserve(_reserveAddress);
        bridgeInstance = IBridge(_bridgeAddress);
    }

    modifier onlyHandler() {
        require(msg.sender == handlerAddress, "sender must be handler contract");
        _;
    }

    //Function that authorize upgrade caller
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function getExpectedReturn(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    ) public view override returns (uint256 returnAmount, uint256[] memory distribution) {
        (returnAmount, , distribution) = getExpectedReturnWithGas(fromToken, destToken, amount, parts, flags, 0);
    }

    function getExpectedReturnETH(
        IERC20Upgradeable srcStableFromToken,
        uint256 srcStableFromTokenAmount,
        uint256 parts,
        uint256 flags
    ) public view override returns (uint256 returnAmount) {
        if (address(srcStableFromToken) == address(MATIC_ADDRESS)) {
            srcStableFromToken = wmatic;
        }
        (returnAmount, ) = getExpectedReturn(srcStableFromToken, weth, srcStableFromTokenAmount, parts, flags);
        return returnAmount;
    }

    function getExpectedReturnWithGas(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 destTokenEthPriceTimesGasPrice
    )
        public
        view
        override
        returns (
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        return
            oneSplitView.getExpectedReturnWithGas(
                fromToken,
                destToken,
                amount,
                parts,
                flags,
                destTokenEthPriceTimesGasPrice
            );
    }

    function getExpectedReturnWithGasMulti(
        IERC20Upgradeable[] memory tokens,
        uint256 amount,
        uint256[] memory parts,
        uint256[] memory flags,
        uint256[] memory destTokenEthPriceTimesGasPrices
    )
        public
        view
        override
        returns (
            uint256[] memory returnAmounts,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        uint256[] memory dist;

        returnAmounts = new uint256[](tokens.length - 1);
        for (uint256 i = 1; i < tokens.length; i++) {
            if (tokens[i - 1] == tokens[i]) {
                returnAmounts[i - 1] = (i == 1) ? amount : returnAmounts[i - 2];
                continue;
            }

            IERC20Upgradeable[] memory _tokens = tokens;

            (returnAmounts[i - 1], amount, dist) = getExpectedReturnWithGas(
                _tokens[i - 1],
                _tokens[i],
                (i == 1) ? amount : returnAmounts[i - 2],
                parts[i - 1],
                flags[i - 1],
                destTokenEthPriceTimesGasPrices[i - 1]
            );
            estimateGasAmount = estimateGasAmount + amount;

            if (distribution.length == 0) {
                distribution = new uint256[](dist.length);
            }

            for (uint256 j = 0; j < distribution.length; j++) {
                distribution[j] = (distribution[j] + dist[j]) << (8 * (i - 1));
            }
        }
    }

    function setHandlerAddress(address _handlerAddress) public override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(_handlerAddress != address(0), "Recipient can't be null");
        handlerAddress = _handlerAddress;
        return true;
    }

    function setReserveAddress(address _reserveAddress) public override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(_reserveAddress != address(0), "Address can't be null");
        reserveInstance = IHandlerReserve(_reserveAddress);
        return true;
    }

    function setBridgeAddress(address _bridgeAddress) public override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(_bridgeAddress != address(0), "Address can't be null");
        bridgeInstance = IBridge(_bridgeAddress);
        return true;
    }

    function setEthHandler(IEthHandler ethHandler) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _ethHandler = ethHandler;
    }

    function withdraw(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public payable override onlyHandler returns (bool) {
        require(tokenAddress != address(0), "Token address can't be null");
        require(recipient != address(0), "Recipient can't be null");

        TransferHelper.safeTransfer(tokenAddress, recipient, amount);
        return true;
    }

    function swap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 minReturn,
        uint256 flags,
        bool isWrapper
    ) public payable override returns (uint256 returnAmount) {
        if (!isWrapper) {
            fromToken.universalTransferFrom(msg.sender, address(this), amount);
        }

        uint256 confirmed = fromToken.universalBalanceOf(address(this));
        _swapFloor(fromToken, destToken, confirmed, flags);
        returnAmount = destToken.universalBalanceOf(address(this));
        require(returnAmount >= minReturn, "RA: actual return amount is less than minReturn");
        destToken.universalTransfer(msg.sender, returnAmount);
        fromToken.universalTransfer(msg.sender, fromToken.universalBalanceOf(address(this)));
        return returnAmount;
    }

    function swapMulti(
        IERC20Upgradeable[] memory tokens,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory flags,
        bool isWrapper
    ) public payable override returns (uint256 returnAmount) {
        if (!isWrapper) {
            tokens[0].universalTransferFrom(msg.sender, address(this), amount);
        }

        returnAmount = tokens[0].universalBalanceOf(address(this));
        for (uint256 i = 1; i < tokens.length; i++) {
            if (tokens[i - 1] == tokens[i]) {
                continue;
            }
            _swapFloor(tokens[i - 1], tokens[i], returnAmount, flags[i - 1]);
            returnAmount = tokens[i].universalBalanceOf(address(this));
            tokens[i - 1].universalTransfer(msg.sender, tokens[i - 1].universalBalanceOf(address(this)));
        }

        require(returnAmount >= minReturn, "RA: actual return amount is less than minReturn");
        tokens[tokens.length - 1].universalTransfer(msg.sender, returnAmount);
    }

    function _swapFloor(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 flags
    ) internal {
        _swap(fromToken, destToken, amount, 0, flags);
    }

    function _getReserveExchange(uint256 flag)
        internal
        pure
        returns (function(IERC20Upgradeable, IERC20Upgradeable, uint256, uint256))
    {
        if (flag.check(FLAG_DISABLE_UNISWAP_ALL | FLAG_DISABLE_UNISWAP)) {
            return _swapOnUniswap;
        } else if (flag.check(FLAG_DISABLE_UNISWAP_V2_ALL | FLAG_DISABLE_UNISWAP_V2)) {
            return _swapOnUniswapV2;
        } else if (flag.check(FLAG_DISABLE_DFYN)) {
            return _swapOnDfyn;
        } else if (flag.check(FLAG_DISABLE_PANCAKESWAP)) {
            return _swapOnPancakeSwap;
        } else if (flag.check(FLAG_DISABLE_QUICKSWAP)) {
            return _swapOnQuickSwap;
        }
        revert("RA: Exchange not found");
    }

    function _swap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 minReturn,
        uint256 flags
    ) internal returns (uint256 returnAmount) {
        if (fromToken == destToken) {
            return amount;
        }

        if (
            (reserveInstance._contractToLP(address(destToken)) == address(fromToken)) &&
            (destToken.universalBalanceOf(address(reserveInstance)) > amount)
        ) {
            bridgeInstance.unstake(handlerAddress, address(destToken), amount);
            return amount;
        }

        if (reserveInstance._lpToContract(address(destToken)) == address(fromToken)) {
            fromToken.universalApprove(address(reserveInstance), amount);
            bridgeInstance.stake(handlerAddress, address(fromToken), amount);
            return amount;
        }

        function(IERC20Upgradeable, IERC20Upgradeable, uint256, uint256) reserve = _getReserveExchange(flags);

        uint256 remainingAmount = fromToken.universalBalanceOf(address(this));
        reserve(fromToken, destToken, remainingAmount, flags);

        returnAmount = destToken.universalBalanceOf(address(this));
        require(returnAmount >= minReturn, "Return amount was not enough");
    }

    receive() external payable {}

    function _swapOnUniswap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal {
        uint256 returnAmount = amount;

        if (!fromToken.isETH()) {
            IUniswapExchange fromExchange = uniswapFactory.getExchange(fromToken);
            if (fromExchange != IUniswapExchange(address(0))) {
                fromToken.universalApprove(address(fromExchange), returnAmount);
                returnAmount = fromExchange.tokenToEthSwapInput(returnAmount, 1, block.timestamp);
            }
        }

        if (!destToken.isETH()) {
            IUniswapExchange toExchange = uniswapFactory.getExchange(destToken);
            if (toExchange != IUniswapExchange(address(0))) {
                returnAmount = toExchange.ethToTokenSwapInput{ value: returnAmount }(1, block.timestamp);
            }
        }
    }

    function _swapOnDfynInternal(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal returns (uint256 returnAmount) {
        if (fromToken.isETH()) {
            wmatic.deposit{ value: amount }();
        }

        IERC20Upgradeable fromTokenReal = fromToken.isETH() ? wmatic : fromToken;
        IERC20Upgradeable toTokenReal = destToken.isETH() ? wmatic : destToken;
        IUniswapV2Exchange exchange = dfynExchange.getPair(fromTokenReal, toTokenReal);
        bool needSync;
        bool needSkim;
        (returnAmount, needSync, needSkim) = exchange.getReturn(fromTokenReal, toTokenReal, amount);
        if (needSync) {
            exchange.sync();
        } else if (needSkim) {
            exchange.skim(skimAddress);
        }

        fromTokenReal.universalTransfer(address(exchange), amount);
        if (uint256(uint160(address(fromTokenReal))) < uint256(uint160(address(toTokenReal)))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (destToken.isETH()) {
            // wmatic.withdraw(wmatic.balanceOf(address(this)));
            uint256 balanceThis = wmatic.balanceOf(address(this));
            wmatic.transfer(address(_ethHandler), wmatic.balanceOf(address(this)));
            _ethHandler.withdraw(address(wmatic), balanceThis);
        }
    }

    function __swapOnPancakeSwapInternal(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal returns (uint256 returnAmount) {
        if (fromToken.isETH()) {
            wbnb.deposit{ value: amount }();
        }

        IERC20Upgradeable fromTokenReal = fromToken.isETH() ? wbnb : fromToken;
        IERC20Upgradeable toTokenReal = destToken.isETH() ? wbnb : destToken;
        IUniswapV2Exchange exchange = pancakeSwap.getPair(fromTokenReal, toTokenReal);
        bool needSync;
        bool needSkim;
        (returnAmount, needSync, needSkim) = exchange.getReturn(fromTokenReal, toTokenReal, amount);
        if (needSync) {
            exchange.sync();
        } else if (needSkim) {
            exchange.skim(skimAddress);
        }

        fromTokenReal.universalTransfer(address(exchange), amount);
        if (uint256(uint160(address(fromTokenReal))) < uint256(uint160(address(toTokenReal)))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (destToken.isETH()) {
            // wbnb.withdraw(wbnb.balanceOf(address(this)));
            uint256 balanceThis = wbnb.balanceOf(address(this));
            wbnb.transfer(address(_ethHandler), wbnb.balanceOf(address(this)));
            _ethHandler.withdraw(address(wbnb), balanceThis);
        }
    }

    function __swapOnQuickSwapInternal(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal returns (uint256 returnAmount) {
        if (fromToken.isETH()) {
            wmatic.deposit{ value: amount }();
        }

        IERC20Upgradeable fromTokenReal = fromToken.isETH() ? wmatic : fromToken;
        IERC20Upgradeable toTokenReal = destToken.isETH() ? wmatic : destToken;
        IUniswapV2Exchange exchange = quickSwap.getPair(fromTokenReal, toTokenReal);
        bool needSync;
        bool needSkim;
        (returnAmount, needSync, needSkim) = exchange.getReturn(fromTokenReal, toTokenReal, amount);
        if (needSync) {
            exchange.sync();
        } else if (needSkim) {
            exchange.skim(skimAddress);
        }

        fromTokenReal.universalTransfer(address(exchange), amount);
        if (uint256(uint160(address(fromTokenReal))) < uint256(uint160(address(toTokenReal)))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (destToken.isETH()) {
            uint256 balanceThis = wmatic.balanceOf(address(this));
            wmatic.transfer(address(_ethHandler), wmatic.balanceOf(address(this)));
            _ethHandler.withdraw(address(wmatic), balanceThis);
        }
    }

    function _swapOnUniswapV2Internal(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 /*flags*/
    ) internal returns (uint256 returnAmount) {
        if (fromToken.isETH()) {
            weth.deposit{ value: amount }();
        }

        IERC20Upgradeable fromTokenReal = fromToken.isETH() ? weth : fromToken;
        IERC20Upgradeable toTokenReal = destToken.isETH() ? weth : destToken;
        IUniswapV2Exchange exchange = uniswapV2.getPair(fromTokenReal, toTokenReal);
        bool needSync;
        bool needSkim;
        (returnAmount, needSync, needSkim) = exchange.getReturn(fromTokenReal, toTokenReal, amount);
        if (needSync) {
            exchange.sync();
        } else if (needSkim) {
            exchange.skim(skimAddress);
        }

        fromTokenReal.universalTransfer(address(exchange), amount);
        if (uint256(uint160(address(fromTokenReal))) < uint256(uint160(address(toTokenReal)))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (destToken.isETH()) {
            // weth.withdraw(weth.balanceOf(address(this)));
            uint256 balanceThis = weth.balanceOf(address(this));
            weth.transfer(address(_ethHandler), weth.balanceOf(address(this)));
            _ethHandler.withdraw(address(weth), balanceThis);
        }
    }

    function _swapOnUniswapV2(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 flags
    ) internal {
        _swapOnUniswapV2Internal(fromToken, destToken, amount, flags);
    }

    function _swapOnDfyn(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 flags
    ) internal {
        _swapOnDfynInternal(fromToken, destToken, amount, flags);
    }

    function _swapOnPancakeSwap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 flags
    ) internal {
        __swapOnPancakeSwapInternal(fromToken, destToken, amount, flags);
    }

    function _swapOnQuickSwap(
        IERC20Upgradeable fromToken,
        IERC20Upgradeable destToken,
        uint256 amount,
        uint256 flags
    ) internal {
        __swapOnQuickSwapInternal(fromToken, destToken, amount, flags);
    }
}