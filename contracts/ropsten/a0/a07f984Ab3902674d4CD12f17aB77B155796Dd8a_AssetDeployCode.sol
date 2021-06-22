// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./pancake-swap/interfaces/IPancakeRouter02.sol";
import "./pancake-swap/interfaces/IWETH.sol";

import "./interfaces/IAsset.sol";
import "./interfaces/IStaking.sol";

import "./InitialAsset.sol";
import "./lib/AssetLib.sol";
import "./lib/AssetLib2.sol";

contract Asset is InitialAsset, IAsset {
    /* STATE VARIABLES */

    // public data
    address public dexRouter;
    address public zVault;

    address[] public tokensInAsset;
    mapping(address => uint256) public tokensDistribution;
    mapping(address => uint256) public xVaultAmount;
    mapping(address => uint256) public yVaultAmount;
    mapping(address => uint256) public yVaultAmountInStaking;
    mapping(address => uint256) public totalTokenAmount;

    bool public isAllowedAutoXYRebalace = true;

    uint256 public feeLimitForAuto = 10 ether;
    uint256 public feeLimitForAutoInAssetToken = 10 ether;
    uint256 public feeAmountToZ;
    uint256 public feeAmountInAssetToken;

    // private data
    uint256 private constant INITIAL_ASSET_AMOUNT = 1e6 * 1e18;
    mapping(address => uint256) private _allowanceToDexInfo;
    bool private isRedeemingFee;

    /* MODIFIERS */

    modifier onlyAfterIme {
        require(isImeHelded == true, "Ime is not ended");
        _;
    }

    /* EVENTS */
    /* FUNCTIONS */

    constructor() {}

    receive() external payable {
        require(_msgSender() == _weth, "Now allowed");
    }

    /* EXTERNAL FUNCTIONS */

    function __Asset_init(
        string memory name,
        string memory symbol,
        address[3] memory oracleDexRouterAndZVault,
        uint256[2] memory imeTimeInfo,
        address[] calldata _tokenWhitelist,
        address[] calldata _tokensInAsset,
        uint256[] calldata _tokensDistribution
    ) external override initializer {
        address weth_ = IPancakeRouter02(oracleDexRouterAndZVault[1]).WETH();
        InitialAsset.__InitialAsset_init(
            name,
            symbol,
            oracleDexRouterAndZVault[0],
            imeTimeInfo[0],
            imeTimeInfo[1],
            _tokenWhitelist,
            weth_
        );

        dexRouter = oracleDexRouterAndZVault[1];
        zVault = oracleDexRouterAndZVault[2];

        tokensInAsset = _tokensInAsset;

        AssetLib.checkAndWriteDistribution(
            _tokensInAsset,
            _tokensDistribution,
            _tokensInAsset,
            tokensDistribution
        );
    }

    function mint(address tokenToPay, uint256 amount) external payable override onlyAfterIme {
        address sender = _msgSender();
        // recieve senders funds
        uint256 totalWeth;
        address weth_ = _weth;
        address _dexRouter = dexRouter;
        (tokenToPay, totalWeth) = AssetLib.transferTokenAndSwapToWeth(
            tokenToPay,
            amount,
            sender,
            weth_,
            _dexRouter,
            _allowanceToDexInfo
        );
        require(isTokenWhitelisted[tokenToPay] == true, "Not allowed token to pay");

        {
            // 0.5%
            uint256 feeAmount = (totalWeth * 50) / 1e4;
            feeAmountToZ += feeAmount;
            totalWeth -= feeAmount;
        }

        // buy tokens in asset
        address[] memory _tokensInAsset = tokensInAsset;
        (uint256[] memory buyAmounts, uint256[] memory oldDistribution) =
            AssetLib.buyTokensMint(
                totalWeth,
                _tokensInAsset,
                [weth_, _dexRouter],
                tokensDistribution,
                totalTokenAmount,
                _allowanceToDexInfo
            );

        AssetLib2.xyDistributionAfterMint(
            _tokensInAsset,
            buyAmounts,
            oldDistribution,
            xVaultAmount,
            yVaultAmount
        );

        // get mint amount
        uint256 mintAmount =
            AssetLib.getMintAmount(
                _tokensInAsset,
                buyAmounts,
                oldDistribution,
                totalSupply(),
                decimals(),
                oracle
            );
        _mint(sender, mintAmount);

        _autoTransferFee(false);
    }

    function redeem(uint256 amount, address currencyToPay) public override returns (uint256) {
        bool _isRedeemingFee = isRedeemingFee;
        address sender;
        if (_isRedeemingFee == true) {
            sender = address(this);
        } else {
            sender = _msgSender();
        }
        address weth_ = _weth;
        {
            address currencyToCheck;
            if (currencyToPay == address(0)) {
                currencyToCheck = weth_;
            } else {
                currencyToCheck = currencyToPay;
            }
            require(isTokenWhitelisted[currencyToCheck], "Not allowed currency");
        }

        uint256 _totalSupply = totalSupply();
        _burn(sender, amount);

        address[] memory _tokensInAsset = tokensInAsset;
        uint256[] memory feePercentages;
        if (_isRedeemingFee == true) {
            feePercentages = new uint256[](_tokensInAsset.length);
        } else {
            feePercentages = AssetLib.getFeePercentagesRedeem(
                _tokensInAsset,
                totalTokenAmount,
                xVaultAmount
            );
        }

        (uint256 feeTotal, uint256[] memory inputAmounts, uint256 outputAmountTotal) =
            AssetLib.redeemAndTransfer(
                [amount, _totalSupply],
                [sender, currencyToPay, weth_, dexRouter],
                totalTokenAmount,
                _allowanceToDexInfo,
                _tokensInAsset,
                feePercentages
            );

        if (feeTotal > 0 && currencyToPay != address(0) && currencyToPay != weth_) {
            feeAmountToZ += AssetLib.safeSwap(
                [currencyToPay, weth_],
                feeTotal,
                dexRouter,
                _allowanceToDexInfo
            );
        } else if (feeTotal > 0) {
            feeAmountToZ += feeTotal;
        }

        AssetLib2.xyDistributionAfterRedeem(
            totalTokenAmount,
            isAllowedAutoXYRebalace,
            xVaultAmount,
            yVaultAmount,
            _tokensInAsset,
            inputAmounts
        );

        if (_isRedeemingFee == false) {
            _autoTransferFee(false);
        }

        return outputAmountTotal;
    }

    function makeIme() external nonReentrant onlyManagerOrAdmin {
        _proceedIme(INITIAL_ASSET_AMOUNT);

        {
            uint256 totalWeightIme_ = _totalWeightIme;
            if (totalWeightIme_ == 0) {
                return;
            }

            address[] memory _tokenWhitelist = tokenWhitelist;
            uint256[][3] memory tokensIncomeAmounts =
                AssetLib.initTokenInfoFromWhitelist(_tokenWhitelist, tokenEntersIme);

            _rebase(_tokenWhitelist, tokensIncomeAmounts, totalWeightIme_, tokensInAsset, true);
        }

        AssetLib.calculateXYAfterIme(tokensInAsset, totalTokenAmount, xVaultAmount, yVaultAmount);
    }

    function rebase(address[] calldata newTokensInAsset, uint256[] calldata distribution)
        external
        onlyManagerOrAdmin
        onlyAfterIme
        nonReentrant
    {
        require(newTokensInAsset.length == distribution.length, "Input error");

        address[] memory _tokensOld = tokensInAsset;
        // fill information about tokens that already in asset and calculate weight of tokens in asset now
        (uint256[][3] memory _tokensOldInfo, uint256 oldWeight) =
            AssetLib.initTokenToSellInfo(_tokensOld, oracle, totalTokenAmount);

        // check new distribution
        AssetLib.checkAndWriteDistribution(
            newTokensInAsset,
            distribution,
            _tokensOld,
            tokensDistribution
        );

        tokensInAsset = newTokensInAsset;

        _rebase(_tokensOld, _tokensOldInfo, oldWeight, newTokensInAsset, false);
    }

    function withdrawTokensForStaking(uint256[] memory tokenAmounts)
        external
        nonReentrant
        onlyManagerOrAdmin
    {
        AssetLib.withdrawFromYForOwner(
            tokensInAsset,
            tokenAmounts,
            _msgSender(),
            yVaultAmount,
            yVaultAmountInStaking
        );
    }

    function xyRebalance(uint256 xPercentage) external nonReentrant onlyManagerOrAdmin {
        require(xPercentage <= 2000, "Wrong X percentage");

        AssetLib2.xyRebalance(
            xPercentage,
            tokensInAsset,
            xVaultAmount,
            yVaultAmount,
            totalTokenAmount
        );
    }

    function depositToIndex(
        uint256[] memory tokenAmountsOfY,
        address[] memory tokensOfDividends,
        uint256[] memory amountOfDividends
    ) external payable nonReentrant onlyManagerOrAdmin {
        address weth_ = _weth;
        feeAmountToZ += AssetLib.depositToY(
            tokensInAsset,
            tokenAmountsOfY,
            tokensOfDividends,
            amountOfDividends,
            _msgSender(),
            dexRouter,
            weth_,
            _allowanceToDexInfo,
            yVaultAmountInStaking,
            yVaultAmount
        );

        if (msg.value > 0) {
            IWETH(weth_).deposit{ value: msg.value }();
            feeAmountToZ += msg.value;
        }

        _autoTransferFee(false);
    }

    function forceFeesAutosend() external nonReentrant onlyManagerOrAdmin {
        _autoTransferFee(true);
    }

    function setIsAllowedAutoXYRebalace(bool value) external onlyManagerOrAdmin {
        isAllowedAutoXYRebalace = value;
    }

    function setFeeLimits(uint256 _feeLimitForAuto, uint256 _feeLimitForAutoInAssetToken)
        external
        onlyManagerOrAdmin
    {
        feeLimitForAuto = _feeLimitForAuto;
        feeLimitForAutoInAssetToken = _feeLimitForAutoInAssetToken;
    }

    function getBuyAmountOut(address currencyIn, uint256 amountIn) external view returns (uint256) {
        return
            AssetLib2.calculateBuyAmountOut(
                amountIn,
                currencyIn,
                tokensInAsset,
                [_weth, dexRouter, address(oracle)],
                totalSupply(),
                decimals(),
                tokensDistribution,
                totalTokenAmount
            );
    }

    function getSellAmountOut(address currencyOut, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return
            AssetLib2.calculateSellAmountOut(
                [amountIn, totalSupply()],
                currencyOut,
                tokensInAsset,
                [_weth, dexRouter],
                totalTokenAmount,
                xVaultAmount
            );
    }

    function tokensInAssetLen() external view returns (uint256) {
        return tokensInAsset.length;
    }

    /* PUBLIC FUNCTIONS */
    /* INTERNAL FUNCTIONS */

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        address _zVault = zVault;
        if (sender != _zVault && recipient != _zVault) {
            uint256 feeAmount = (amount * 25) / 1e4;
            feeAmountInAssetToken += feeAmount;
            super._transfer(sender, address(this), feeAmount);
            super._transfer(sender, recipient, amount - feeAmount);
        } else {
            super._transfer(sender, recipient, amount);
        }
    }

    /* PRIVATE FUNCTIONS */

    function _autoTransferFee(bool isForce) private {
        uint256 _feeLimitForAuto = feeLimitForAuto;
        uint256 _feeLimitForAutoInAssetToken = feeLimitForAutoInAssetToken;
        uint256 _feeAmountToZ = feeAmountToZ;
        uint256 _feeAmountInAssetToken = feeAmountInAssetToken;

        uint256 totalAmountFee;
        if (_feeAmountToZ > 0 && (isForce || _feeAmountToZ >= _feeLimitForAuto)) {
            IWETH(_weth).withdraw(_feeAmountToZ);
            totalAmountFee += _feeAmountToZ;
            feeAmountToZ = 0;
        }

        if (
            _feeAmountInAssetToken > 0 &&
            (isForce || _feeAmountInAssetToken >= _feeLimitForAutoInAssetToken)
        ) {
            isRedeemingFee = true;
            //require(balanceOf(address(this)) >= _feeAmountInAssetToken,  "Internal error 11");
            totalAmountFee += redeem(_feeAmountInAssetToken, address(0));
            isRedeemingFee = false;
            feeAmountInAssetToken = 0;
        }

        if (totalAmountFee > 0) {
            IStaking(zVault).inputBnb{value: totalAmountFee}();
        }
    }

    /*
    tokensInAssetNowInfo
    0 - tokens in assets amounts
    1 - with zero values (in function used for number to sell)
    2 - tokens decimals
    */
    function _rebase(
        address[] memory tokensInAssetNow,
        uint256[][3] memory tokensInAssetNowInfo,
        uint256 totalWeightNow,
        address[] memory tokensToBuy,
        bool isIme
    ) private {
        //address[] memory tokensToBuy = tokensInAsset;
        /*
        tokenToBuyInfo
        0 - tokens to buy amounts
        1 - actual number to buy (tokens to buy amounts - tokensInAssetNow)
        2 - actual weight to buy
        3 - tokens decimals
        4 - is in asset already
         */
        (uint256[][5] memory tokenToBuyInfo, uint256[] memory tokensPrices) =
            AssetLib.initTokenToBuyInfo(tokensToBuy, totalWeightNow, tokensDistribution, oracle);

        // we can assume that here we don't need to check isValidValue array

        // here we calculate actual number of assets to buy
        // considering that some tokens may be in asset already
        // and also calculate how many tokens we need to sell that are in asset already
        // after that we calculate weight (to buy) of tokens that are not in asset yet

        // tokenToBuyInfoGlobals info
        // 0 - total weight to buy
        // 1 - number of true tokens to buy
        uint256[2] memory tokenToBuyInfoGlobals;
        (tokensInAssetNowInfo, tokenToBuyInfo, tokenToBuyInfoGlobals) = AssetLib
            .fillInformationInSellAndBuyTokens(
            tokensInAssetNow,
            tokensInAssetNowInfo,
            tokensToBuy,
            tokenToBuyInfo,
            tokensPrices
        );

        // here we sell tokens that are needed to be sold
        address weth_ = _weth;
        address _dexRouter = dexRouter;
        uint256 availableWeth =
            AssetLib.sellTokensInAssetNow(
                tokensInAssetNow,
                tokensInAssetNowInfo,
                weth_,
                _dexRouter,
                totalTokenAmount,
                _allowanceToDexInfo
            );

        // here we buy tokens that are needed to be bought
        uint256[] memory outputAmounts =
            AssetLib.buyTokensInAssetRebase(
                tokensToBuy,
                tokenToBuyInfo,
                tokenToBuyInfoGlobals,
                weth_,
                _dexRouter,
                availableWeth,
                totalTokenAmount,
                _allowanceToDexInfo
            );

        if (isIme == false) {
            AssetLib2.xyDistributionAfterRebase(
                tokensInAssetNow,
                tokensInAssetNowInfo[1],
                tokensToBuy,
                outputAmounts,
                xVaultAmount,
                yVaultAmount,
                totalTokenAmount
            );
        }
    }
}