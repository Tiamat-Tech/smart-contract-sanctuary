// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./pancake-swap/interfaces/IPancakeRouter02.sol";
import "./pancake-swap/interfaces/IWETH.sol";

import "./interfaces/IAsset.sol";
import "./interfaces/IStaking.sol";

import "./lib/AssetLib.sol";
import "./lib/AssetLib2.sol";

// solhint-disable-next-line max-states-count
contract Asset is ERC20Upgradeable, ReentrancyGuard, IAsset {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* STATE VARIABLES */

    // public data
    // whitelist info
    address public zVault;
    IOracle public oracle;
    address public factory;

    uint256 public imeStartTimestamp;
    uint256 public imeEndTimestamp;
    uint256 public initialPrice;

    address[] public tokensInAsset;
    mapping(address => uint256) public tokensDistribution;
    mapping(address => uint256) public xVaultAmount;
    mapping(address => uint256) public yVaultAmount;
    mapping(address => uint256) public yVaultAmountInStaking;
    mapping(address => uint256) public totalTokenAmount;

    bool public isAllowedAutoXYRebalace = true;
    bool public mintPaused;

    uint256 public feeLimitForAuto = 10 ether;
    uint256 public feeLimitForAutoInAssetToken = 10 ether;
    uint256 public feeAmountToZ;
    uint256 public feeAmountInAssetToken;

    // private data
    address private _weth;
    bytes32 private constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    mapping(address => uint256) private _whitelistIndexes;

    EnumerableSet.AddressSet private _tokenWhitelistSet;

    /* MODIFIERS */

    modifier onlyManagerOrAdmin {
        require(
            AccessControl(factory).hasRole(MANAGER_ROLE, _msgSender()) ||
                AccessControl(factory).hasRole(0x00, _msgSender()),
            "Access error"
        );
        _;
    }

    /* EVENTS */

    event MintAsset(
        address indexed user,
        address indexed tokenEnter,
        uint256 amountEnter,
        uint256 amountMinted,
        address[] tokensInAsset,
        uint256[] buyAmounts
    );
    event RedeemAsset(
        address indexed user,
        address indexed tokenExit,
        uint256 amountOfTokenExit,
        uint256 amountOfAssetExit,
        address[] tokensInAsset,
        uint256[] sellAmounts,
        uint256[] feePercentages
    );
    event Rebase(
        address[] tokensOld,
        uint256[] sellAmounts,
        address[] tokensNew,
        uint256[] buyAmounts,
        bool isIme
    );
    event NewDistribution(address[] tokens, uint256[] newDistribution);
    event WithdrawTokens(address[] tokens, uint256[] amounts);
    event XyManualRebalance(uint256 newPercentage);
    event DepositToAsset(
        address[] tokensInAsset,
        uint256[] tokenAmountsToY,
        address[] tokensOfDividends,
        uint256[] amountOfDividends
    );
    event AssetsFromFeesConvertedToWeth(uint256 assetAmount, uint256 wethAmount);
    event TransferFeesInZVault(uint256 feeAmount);
    event PauseStateChanged(bool indexed isMintPaused);

    /* FUNCTIONS */

    // solhint-disable-next-line func-visibility
    constructor() {
        factory = _msgSender();
    }

    receive() external payable {
        require(_msgSender() == _weth, "Now allowed");
    }

    /* EXTERNAL FUNCTIONS */

    // solhint-disable-next-line func-name-mixedcase
    function __Asset_init(
        string[2] memory nameSymbol,
        address[3] memory oracleZVaultAndWeth,
        uint256[3] memory imeTimeInfoAndInitialPrice,
        address[] calldata _tokenWhitelist,
        address[] calldata _tokensInAsset,
        uint256[] calldata _tokensDistribution
    ) external override initializer {
        __ERC20_init(nameSymbol[0], nameSymbol[1]);

        require(
            // solhint-disable-next-line not-rely-on-time
            imeTimeInfoAndInitialPrice[0] >= block.timestamp &&
                imeTimeInfoAndInitialPrice[0] < imeTimeInfoAndInitialPrice[1],
            "Time error"
        );
        imeStartTimestamp = imeTimeInfoAndInitialPrice[0];
        imeEndTimestamp = imeTimeInfoAndInitialPrice[1];
        require(imeTimeInfoAndInitialPrice[2] > 0, "Initial price error");
        initialPrice = imeTimeInfoAndInitialPrice[2];

        oracle = IOracle(oracleZVaultAndWeth[0]);
        _weth = oracleZVaultAndWeth[2];
        zVault = oracleZVaultAndWeth[1];

        address _factory = factory;
        AssetLib.checkAndWriteWhitelist(_tokenWhitelist, _factory, _tokenWhitelistSet);

        AssetLib.checkIfTokensHavePair(_tokensInAsset, _factory);
        tokensInAsset = _tokensInAsset;
        AssetLib.checkAndWriteDistribution(
            _tokensInAsset,
            _tokensDistribution,
            _tokensInAsset,
            tokensDistribution
        );
    }

    function mint(address tokenToPay, uint256 amount)
        external
        payable
        override
        nonReentrant
        returns (uint256)
    {
        require(!mintPaused, "Paused");
        // recieve senders funds
        uint256 totalWeth;
        address factory_ = factory;
        address weth_ = _weth;
        address sender = _msgSender();
        (tokenToPay, totalWeth) = AssetLib.transferTokenAndSwapToWeth(
            tokenToPay,
            amount,
            sender,
            weth_,
            factory_
        );
        require(_tokenWhitelistSet.contains(tokenToPay), "Not allowed token to pay");

        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= imeStartTimestamp, "Not opened");
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp >= imeEndTimestamp) {
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
                [weth_, factory_],
                tokensDistribution,
                totalTokenAmount
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
                oracle,
                initialPrice
            );
        _mint(sender, mintAmount);

        _autoTransferFee(false);

        emit MintAsset(sender, tokenToPay, amount, mintAmount, _tokensInAsset, buyAmounts);

        return mintAmount;
    }

    function redeem(uint256 amount, address currencyToPay)
        external
        override
        nonReentrant
        returns (uint256)
    {
        return _redeem(amount, currencyToPay, false);
    }

    function changePauseState() external onlyManagerOrAdmin {
        bool _mintPaused = mintPaused;
        if (_mintPaused) {
            mintPaused = false;
        } else {
            mintPaused = true;
        }
        emit PauseStateChanged(!_mintPaused);
    }

    function rebase(address[] calldata newTokensInAsset, uint256[] calldata distribution)
        external
        onlyManagerOrAdmin
        /* onlyAfterIme */
        nonReentrant
    {
        require(block.timestamp >= imeEndTimestamp, "Not opened");

        AssetLib.checkIfTokensHavePair(newTokensInAsset, factory);

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

        emit NewDistribution(newTokensInAsset, distribution);
    }

    function withdrawTokensForStaking(uint256[] memory tokenAmounts)
        external
        nonReentrant
        onlyManagerOrAdmin
    {
        address[] memory _tokensInAsset = tokensInAsset;
        AssetLib.withdrawFromYForOwner(
            _tokensInAsset,
            tokenAmounts,
            _msgSender(),
            yVaultAmount,
            yVaultAmountInStaking
        );

        emit WithdrawTokens(_tokensInAsset, tokenAmounts);
    }

    function xyRebalance(uint256 xPercentage) external nonReentrant onlyManagerOrAdmin {
        require(xPercentage >= 500 && xPercentage <= 2000, "Wrong X percentage");

        AssetLib2.xyRebalance(
            xPercentage,
            tokensInAsset,
            xVaultAmount,
            yVaultAmount,
            totalTokenAmount
        );

        emit XyManualRebalance(xPercentage);
    }

    function depositToIndex(
        uint256[] memory tokenAmountsOfY,
        address[] memory tokensOfDividends,
        uint256[] memory amountOfDividends
    ) external payable nonReentrant onlyManagerOrAdmin {
        address weth_ = _weth;
        address[] memory _tokensInAsset = tokensInAsset;
        feeAmountToZ += AssetLib.depositToY(
            _tokensInAsset,
            tokenAmountsOfY,
            tokensOfDividends,
            amountOfDividends,
            _msgSender(),
            factory,
            weth_,
            yVaultAmountInStaking,
            yVaultAmount
        );

        if (msg.value > 0) {
            IWETH(weth_).deposit{value: msg.value}();
            feeAmountToZ += msg.value;
        }

        _autoTransferFee(false);

        emit DepositToAsset(_tokensInAsset, tokenAmountsOfY, tokensOfDividends, amountOfDividends);
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

    function changeIsTokenWhitelisted(address token, bool value)
        external
        onlyManagerOrAdmin
        nonReentrant
    {
        AssetLib.changeWhitelist(token, value, factory, _tokenWhitelistSet);
    }

    function getBuyAmountOut(address currencyIn, uint256 amountIn) external view returns (uint256) {
        return
            AssetLib2.calculateBuyAmountOut(
                amountIn,
                currencyIn,
                tokensInAsset,
                [_weth, factory, address(oracle)],
                [totalSupply(), decimals(), initialPrice],
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
                [_weth, factory],
                totalTokenAmount,
                xVaultAmount
            );
    }

    function tokensInAssetLen() external view returns (uint256) {
        return tokensInAsset.length;
    }

    function tokenWhitelistLen() external view returns (uint256) {
        return _tokenWhitelistSet.length();
    }

    function isTokenWhitelisted(address token) external view returns (bool) {
        return _tokenWhitelistSet.contains(token);
    }

    function tokenWhitelist(uint256 index) external view returns (address) {
        return _tokenWhitelistSet.at(index);
    }

    /* PUBLIC FUNCTIONS */
    /* INTERNAL FUNCTIONS */

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        // solhint-disable-next-line not-rely-on-time
        address _zVault = zVault;
        require(block.timestamp >= imeEndTimestamp, "Ime not ended");
        if (sender != _zVault && recipient != _zVault) {
            uint256 feeAmount = (amount * 25) / 1e4;
            super._transfer(sender, recipient, amount - feeAmount);
            if (feeAmount > 0) {
                feeAmountInAssetToken += feeAmount;
                super._transfer(sender, address(this), feeAmount);
                _autoTransferFee(false);
            }
        } else {
            super._transfer(sender, recipient, amount);
        }
    }

    /* PRIVATE FUNCTIONS */

    function _autoTransferFee(bool isForce) private {
        uint256 totalAmountFee;
        uint256 feeAmount = feeAmountToZ;
        if (feeAmount > 0 && (isForce || feeAmount >= feeLimitForAuto)) {
            IWETH(_weth).withdraw(feeAmount);
            totalAmountFee += feeAmount;
            delete feeAmountToZ;
        }

        feeAmount = feeAmountInAssetToken;
        if (feeAmount > 0 && (isForce || feeAmount >= feeLimitForAutoInAssetToken)) {
            feeAmount = _redeem(feeAmount, address(0), true);
            totalAmountFee += feeAmount;
            delete feeAmountInAssetToken;

            emit AssetsFromFeesConvertedToWeth(feeAmount, feeAmount);
        }

        if (totalAmountFee > 0) {
            IStaking(zVault).inputBnb{value: totalAmountFee}();

            emit TransferFeesInZVault(totalAmountFee);
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
        (tokensInAssetNowInfo, tokenToBuyInfo, tokenToBuyInfoGlobals) = AssetLib2
            .fillInformationInSellAndBuyTokens(
            tokensInAssetNow,
            tokensInAssetNowInfo,
            tokensToBuy,
            tokenToBuyInfo,
            tokensPrices
        );

        // here we sell tokens that are needed to be sold
        address weth_ = _weth;
        address _factory = factory;
        uint256 availableWeth =
            AssetLib.sellTokensInAssetNow(
                tokensInAssetNow,
                tokensInAssetNowInfo,
                weth_,
                _factory,
                totalTokenAmount
            );

        // here we buy tokens that are needed to be bought
        //uint256[] memory outputAmounts = new uint256[](tokensToBuy.length);
        uint256[] memory outputAmounts =
            AssetLib.buyTokensInAssetRebase(
                tokensToBuy,
                tokenToBuyInfo,
                tokenToBuyInfoGlobals,
                weth_,
                _factory,
                availableWeth,
                totalTokenAmount
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

        emit Rebase(tokensInAssetNow, tokensInAssetNowInfo[1], tokensToBuy, outputAmounts, isIme);
    }

    function _redeem(
        uint256 amount,
        address currencyToPay,
        bool isRedeemingFee
    ) private returns (uint256) {
        address sender;
        if (isRedeemingFee == true) {
            sender = address(this);
        } else {
            // solhint-disable-next-line not-rely-on-time
            require(block.timestamp >= imeEndTimestamp, "Ime not ended");
            sender = _msgSender();
        }

        address[2] memory factoryAndWeth = [factory, _weth];
        AssetLib.checkCurrency(currencyToPay, factoryAndWeth[1], _tokenWhitelistSet);

        uint256 _totalSupply = totalSupply();
        _burn(sender, amount);

        uint256[] memory feePercentages;
        address[] memory _tokensInAsset = tokensInAsset;
        if (isRedeemingFee == true) {
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
                [sender, currencyToPay, factoryAndWeth[1], factoryAndWeth[0]],
                totalTokenAmount,
                _tokensInAsset,
                feePercentages
            );

        if (feeTotal > 0 && currencyToPay != address(0) && currencyToPay != factoryAndWeth[1]) {
            feeAmountToZ += AssetLib.safeSwap(
                [currencyToPay, factoryAndWeth[1]],
                feeTotal,
                factoryAndWeth[0],
                0
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

        if (isRedeemingFee == false) {
            _autoTransferFee(false);

            emit RedeemAsset(
                sender,
                currencyToPay,
                outputAmountTotal,
                amount,
                _tokensInAsset,
                inputAmounts,
                feePercentages
            );
        }

        return outputAmountTotal;
    }
}