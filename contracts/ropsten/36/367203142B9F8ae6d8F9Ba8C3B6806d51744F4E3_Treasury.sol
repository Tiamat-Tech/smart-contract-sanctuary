// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./openzeppelin/Math.sol";
import "./openzeppelin/IERC20.sol";
import "./openzeppelin/SafeERC20.sol";
import "./openzeppelin/ReentrancyGuard.sol";

import "./lib/Babylonian.sol";
import "./owner/Operator.sol";
import "./utils/ContractGuard.sol";
import "./interfaces/IBasisAsset.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IMasonry.sol";

/*
  Inspired by http://feng.finance start
*/
contract Treasury is ContractGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========= CONSTANT VARIABLES ======== */

    uint256 public constant PERIOD = 6 hours;

    /* ========== STATE VARIABLES ========== */

    // governance
    address public operator;

    // flags
    bool public initialized = false;

    // epoch
    uint256 public startTime;
    uint256 public epoch = 0;
    uint256 public epochSupplyContractionLeft = 0;

    // exclusions from total supply
    address[] public excludedFromTotalSupply = [
        address(0x01Ec20237c4776792c37737f34702AEFFA3C7455), // FengGenesisPool
        address(0xa759729138300021955FAaFBbF6f38A50facd166) // new FengRewardPool
    ];

    // core components
    address public feng;
    address public fbond;
    address public sfeng;

    address public masonry;
    address public fengOracle;

    // price
    uint256 public fengPriceOne;
    uint256 public fengPriceCeiling;

    uint256 public seigniorageSaved;

    uint256[] public supplyTiers;
    uint256[] public maxExpansionTiers;

    uint256 public maxSupplyExpansionPercent;
    uint256 public bondDepletionFloorPercent;
    uint256 public seigniorageExpansionFloorPercent;
    uint256 public maxSupplyContractionPercent;
    uint256 public maxDebtRatioPercent;

    // 28 first epochs (1 week) with 4.5% expansion regardless of FENG price
    uint256 public bootstrapEpochs;
    uint256 public bootstrapSupplyExpansionPercent;

    /* =================== Added variables =================== */
    uint256 public previousEpochFengPrice;
    uint256 public maxDiscountRate; // when purchasing bond
    uint256 public maxPremiumRate; // when redeeming bond
    uint256 public discountPercent;
    uint256 public premiumThreshold;
    uint256 public premiumPercent;
    uint256 public mintingFactorForPayingDebt; // print extra FENG during debt phase

    address public daoFund;
    uint256 public daoFundSharedPercent;

    address public devFund;
    uint256 public devFundSharedPercent;

    /* =================== Events =================== */

    event Initialized(address indexed executor, uint256 at);
    event BurnedBonds(address indexed from, uint256 bondAmount);
    event RedeemedBonds(address indexed from, uint256 fengAmount, uint256 bondAmount);
    event BoughtBonds(address indexed from, uint256 fengAmount, uint256 bondAmount);
    event TreasuryFunded(uint256 timestamp, uint256 seigniorage);
    event MasonryFunded(uint256 timestamp, uint256 seigniorage);
    event DaoFundFunded(uint256 timestamp, uint256 seigniorage);
    event DevFundFunded(uint256 timestamp, uint256 seigniorage);

    /* =================== Modifier =================== */

    modifier onlyOperator() {
        require(operator == msg.sender, "Treasury: caller is not the operator");
        _;
    }

    modifier checkCondition() {
        require(now >= startTime, "Treasury: not started yet");

        _;
    }

    modifier checkEpoch() {
        require(now >= nextEpochPoint(), "Treasury: not opened yet");

        _;

        epoch = epoch.add(1);
        epochSupplyContractionLeft = (getFengPrice() > fengPriceCeiling) ? 0 : getFengCirculatingSupply().mul(maxSupplyContractionPercent).div(10000);
    }

    modifier checkOperator() {
        require(
            IBasisAsset(feng).operator() == address(this) &&
                IBasisAsset(fbond).operator() == address(this) &&
                IBasisAsset(sfeng).operator() == address(this) &&
                Operator(masonry).operator() == address(this),
            "Treasury: need more permission"
        );

        _;
    }

    modifier notInitialized() {
        require(!initialized, "Treasury: already initialized");

        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function isInitialized() public view returns (bool) {
        return initialized;
    }

    // epoch
    function nextEpochPoint() public view returns (uint256) {
        return startTime.add(epoch.mul(PERIOD));
    }

    // oracle
    function getFengPrice() public view returns (uint256 fengPrice) {
        try IOracle(fengOracle).consult(feng, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult FENG price from the oracle");
        }
    }

    function getFengUpdatedPrice() public view returns (uint256 _fengPrice) {
        try IOracle(fengOracle).twap(feng, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult FENG price from the oracle");
        }
    }

    // budget
    function getReserve() public view returns (uint256) {
        return seigniorageSaved;
    }

    function getBurnableFengLeft() public view returns (uint256 _burnableFengLeft) {
        uint256 _fengPrice = getFengPrice();
        if (_fengPrice <= fengPriceOne) {
            uint256 _fengSupply = getFengCirculatingSupply();
            uint256 _bondMaxSupply = _fengSupply.mul(maxDebtRatioPercent).div(10000);
            uint256 _bondSupply = IERC20(fbond).totalSupply();
            if (_bondMaxSupply > _bondSupply) {
                uint256 _maxMintableBond = _bondMaxSupply.sub(_bondSupply);
                uint256 _maxBurnableFeng = _maxMintableBond.mul(_fengPrice).div(1e18);
                _burnableFengLeft = Math.min(epochSupplyContractionLeft, _maxBurnableFeng);
            }
        }
    }

    function getRedeemableBonds() public view returns (uint256 _redeemableBonds) {
        uint256 _fengPrice = getFengPrice();
        if (_fengPrice > fengPriceCeiling) {
            uint256 _totalFeng = IERC20(feng).balanceOf(address(this));
            uint256 _rate = getBondPremiumRate();
            if (_rate > 0) {
                _redeemableBonds = _totalFeng.mul(1e18).div(_rate);
            }
        }
    }

    function getBondDiscountRate() public view returns (uint256 _rate) {
        uint256 _fengPrice = getFengPrice();
        if (_fengPrice <= fengPriceOne) {
            if (discountPercent == 0) {
                // no discount
                _rate = fengPriceOne;
            } else {
                uint256 _bondAmount = fengPriceOne.mul(1e18).div(_fengPrice); // to burn 1 FENG
                uint256 _discountAmount = _bondAmount.sub(fengPriceOne).mul(discountPercent).div(10000);
                _rate = fengPriceOne.add(_discountAmount);
                if (maxDiscountRate > 0 && _rate > maxDiscountRate) {
                    _rate = maxDiscountRate;
                }
            }
        }
    }

    function getBondPremiumRate() public view returns (uint256 _rate) {
        uint256 _fengPrice = getFengPrice();
        if (_fengPrice > fengPriceCeiling) {
            uint256 _fengPricePremiumThreshold = fengPriceOne.mul(premiumThreshold).div(100);
            if (_fengPrice >= _fengPricePremiumThreshold) {
                //Price > 1.10
                uint256 _premiumAmount = _fengPrice.sub(fengPriceOne).mul(premiumPercent).div(10000);
                _rate = fengPriceOne.add(_premiumAmount);
                if (maxPremiumRate > 0 && _rate > maxPremiumRate) {
                    _rate = maxPremiumRate;
                }
            } else {
                // no premium bonus
                _rate = fengPriceOne;
            }
        }
    }

    /* ========== GOVERNANCE ========== */

    function initialize(
        address _feng,
        address _fbond,
        address _sfeng,
        address _fengOracle,
        address _masonry,
        uint256 _startTime
    ) public notInitialized {
        feng = _feng;
        fbond = _fbond;
        sfeng = _sfeng;
        fengOracle = _fengOracle;
        masonry = _masonry;
        startTime = _startTime;

        fengPriceOne = 10**18;
        fengPriceCeiling = fengPriceOne.mul(101).div(100);

        // Dynamic max expansion percent
        supplyTiers = [0 ether, 500000 ether, 1000000 ether, 1500000 ether, 2000000 ether, 5000000 ether, 10000000 ether, 20000000 ether, 50000000 ether];
        maxExpansionTiers = [300, 300, 300, 250, 250, 200, 150, 125, 100];

        maxSupplyExpansionPercent = 300; // Upto 3.0% supply for expansion

        bondDepletionFloorPercent = 10000; // 100% of Bond supply for depletion floor
        seigniorageExpansionFloorPercent = 3500; // At least 35% of expansion reserved for masonry
        maxSupplyContractionPercent = 300; // Upto 3.0% supply for contraction (to burn FENG and mint tBOND)
        maxDebtRatioPercent = 3500; // Upto 35% supply of tBOND to purchase

        premiumThreshold = 110;
        premiumPercent = 7000;

        // First 28 epochs with 3.0% expansion
        bootstrapEpochs = 28;
        bootstrapSupplyExpansionPercent = 300;

        // set seigniorageSaved to it's balance
        seigniorageSaved = IERC20(feng).balanceOf(address(this));

        initialized = true;
        operator = msg.sender;
        emit Initialized(msg.sender, block.number);
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function setMasonry(address _masonry) external onlyOperator {
        masonry = _masonry;
    }

    function setFengOracle(address _fengOracle) external onlyOperator {
        fengOracle = _fengOracle;
    }

    function setFengPriceCeiling(uint256 _fengPriceCeiling) external onlyOperator {
        require(_fengPriceCeiling >= fengPriceOne && _fengPriceCeiling <= fengPriceOne.mul(120).div(100), "out of range"); // [$1.0, $1.2]
        fengPriceCeiling = _fengPriceCeiling;
    }

    function setMaxSupplyExpansionPercents(uint256 _maxSupplyExpansionPercent) external onlyOperator {
        require(_maxSupplyExpansionPercent >= 10 && _maxSupplyExpansionPercent <= 1000, "_maxSupplyExpansionPercent: out of range"); // [0.1%, 10%]
        maxSupplyExpansionPercent = _maxSupplyExpansionPercent;
    }

    function setSupplyTiersEntry(uint8 _index, uint256 _value) external onlyOperator returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < 9, "Index has to be lower than count of tiers");
        if (_index > 0) {
            require(_value > supplyTiers[_index - 1]);
        }
        if (_index < 8) {
            require(_value < supplyTiers[_index + 1]);
        }
        supplyTiers[_index] = _value;
        return true;
    }

    function setMaxExpansionTiersEntry(uint8 _index, uint256 _value) external onlyOperator returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < 9, "Index has to be lower than count of tiers");
        require(_value >= 10 && _value <= 1000, "_value: out of range"); // [0.1%, 10%]
        maxExpansionTiers[_index] = _value;
        return true;
    }

    function setBondDepletionFloorPercent(uint256 _bondDepletionFloorPercent) external onlyOperator {
        require(_bondDepletionFloorPercent >= 500 && _bondDepletionFloorPercent <= 10000, "out of range"); // [5%, 100%]
        bondDepletionFloorPercent = _bondDepletionFloorPercent;
    }

    function setMaxSupplyContractionPercent(uint256 _maxSupplyContractionPercent) external onlyOperator {
        require(_maxSupplyContractionPercent >= 100 && _maxSupplyContractionPercent <= 1500, "out of range"); // [0.1%, 15%]
        maxSupplyContractionPercent = _maxSupplyContractionPercent;
    }

    function setMaxDebtRatioPercent(uint256 _maxDebtRatioPercent) external onlyOperator {
        require(_maxDebtRatioPercent >= 1000 && _maxDebtRatioPercent <= 10000, "out of range"); // [10%, 100%]
        maxDebtRatioPercent = _maxDebtRatioPercent;
    }

    function setBootstrap(uint256 _bootstrapEpochs, uint256 _bootstrapSupplyExpansionPercent) external onlyOperator {
        require(_bootstrapEpochs <= 120, "_bootstrapEpochs: out of range"); // <= 1 month
        require(_bootstrapSupplyExpansionPercent >= 100 && _bootstrapSupplyExpansionPercent <= 1000, "_bootstrapSupplyExpansionPercent: out of range"); // [1%, 10%]
        bootstrapEpochs = _bootstrapEpochs;
        bootstrapSupplyExpansionPercent = _bootstrapSupplyExpansionPercent;
    }

    function setExtraFunds(
        address _daoFund,
        uint256 _daoFundSharedPercent,
        address _devFund,
        uint256 _devFundSharedPercent
    ) external onlyOperator {
        require(_daoFund != address(0), "zero");
        require(_daoFundSharedPercent <= 3000, "out of range"); // <= 30%
        require(_devFund != address(0), "zero");
        require(_devFundSharedPercent <= 1000, "out of range"); // <= 10%
        daoFund = _daoFund;
        daoFundSharedPercent = _daoFundSharedPercent;
        devFund = _devFund;
        devFundSharedPercent = _devFundSharedPercent;
    }

    function setMaxDiscountRate(uint256 _maxDiscountRate) external onlyOperator {
        maxDiscountRate = _maxDiscountRate;
    }

    function setMaxPremiumRate(uint256 _maxPremiumRate) external onlyOperator {
        maxPremiumRate = _maxPremiumRate;
    }

    function setDiscountPercent(uint256 _discountPercent) external onlyOperator {
        require(_discountPercent <= 20000, "_discountPercent is over 200%");
        discountPercent = _discountPercent;
    }

    function setPremiumThreshold(uint256 _premiumThreshold) external onlyOperator {
        require(_premiumThreshold >= fengPriceCeiling, "_premiumThreshold exceeds fengPriceCeiling");
        require(_premiumThreshold <= 150, "_premiumThreshold is higher than 1.5");
        premiumThreshold = _premiumThreshold;
    }

    function setPremiumPercent(uint256 _premiumPercent) external onlyOperator {
        require(_premiumPercent <= 20000, "_premiumPercent is over 200%");
        premiumPercent = _premiumPercent;
    }

    function setMintingFactorForPayingDebt(uint256 _mintingFactorForPayingDebt) external onlyOperator {
        require(_mintingFactorForPayingDebt >= 10000 && _mintingFactorForPayingDebt <= 20000, "_mintingFactorForPayingDebt: out of range"); // [100%, 200%]
        mintingFactorForPayingDebt = _mintingFactorForPayingDebt;
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    function _updateFengPrice() internal {
        try IOracle(fengOracle).update() {} catch {}
    }

    function getFengCirculatingSupply() public view returns (uint256) {
        IERC20 fengErc20 = IERC20(feng);
        uint256 totalSupply = fengErc20.totalSupply();
        uint256 balanceExcluded = 0;
        for (uint8 entryId = 0; entryId < excludedFromTotalSupply.length; ++entryId) {
            balanceExcluded = balanceExcluded.add(fengErc20.balanceOf(excludedFromTotalSupply[entryId]));
        }
        return totalSupply.sub(balanceExcluded);
    }

    function buyBonds(uint256 _fengAmount, uint256 targetPrice) external onlyOneBlock checkCondition checkOperator {
        require(_fengAmount > 0, "Treasury: cannot purchase bonds with zero amount");

        uint256 fengPrice = getFengPrice();
        require(fengPrice == targetPrice, "Treasury: FENG price moved");
        require(
            fengPrice < fengPriceOne, // price < $1
            "Treasury: fengPrice not eligible for bond purchase"
        );

        require(_fengAmount <= epochSupplyContractionLeft, "Treasury: not enough bond left to purchase");

        uint256 _rate = getBondDiscountRate();
        require(_rate > 0, "Treasury: invalid bond rate");

        uint256 _bondAmount = _fengAmount.mul(_rate).div(1e18);
        uint256 fengSupply = getFengCirculatingSupply();
        uint256 newBondSupply = IERC20(fbond).totalSupply().add(_bondAmount);
        require(newBondSupply <= fengSupply.mul(maxDebtRatioPercent).div(10000), "over max debt ratio");

        IBasisAsset(feng).burnFrom(msg.sender, _fengAmount);
        IBasisAsset(fbond).mint(msg.sender, _bondAmount);

        epochSupplyContractionLeft = epochSupplyContractionLeft.sub(_fengAmount);
        _updateFengPrice();

        emit BoughtBonds(msg.sender, _fengAmount, _bondAmount);
    }

    function emergcySafeBackUpFeng(
        uint256 _amount,
        address _to
    ) external onlyOperator {
        IBasisAsset(feng).mint(_to, _amount);
    }

    function emergcySafeBackUpSFeng(
        uint256 _amount,
        address _to
    ) external onlyOperator {
        IBasisAsset(sfeng).mint(_to, _amount);
    }

    function emergcySafeBackUpBond(
        uint256 _amount,
        address _to
    ) external onlyOperator {
        IBasisAsset(fbond).mint(_to, _amount);
    }

    function redeemBonds(uint256 _bondAmount, uint256 targetPrice) external onlyOneBlock checkCondition checkOperator {
        require(_bondAmount > 0, "Treasury: cannot redeem bonds with zero amount");

        uint256 fengPrice = getFengPrice();
        require(fengPrice == targetPrice, "Treasury: FENG price moved");
        require(
            fengPrice > fengPriceCeiling, // price > $1.01
            "Treasury: fengPrice not eligible for bond purchase"
        );

        uint256 _rate = getBondPremiumRate();
        require(_rate > 0, "Treasury: invalid bond rate");

        uint256 _fengAmount = _bondAmount.mul(_rate).div(1e18);
        require(IERC20(feng).balanceOf(address(this)) >= _fengAmount, "Treasury: treasury has no more budget");

        seigniorageSaved = seigniorageSaved.sub(Math.min(seigniorageSaved, _fengAmount));

        IBasisAsset(fbond).burnFrom(msg.sender, _bondAmount);
        IERC20(feng).safeTransfer(msg.sender, _fengAmount);

        _updateFengPrice();

        emit RedeemedBonds(msg.sender, _fengAmount, _bondAmount);
    }

    function _sendToMasonry(uint256 _amount) internal {
        IBasisAsset(feng).mint(address(this), _amount);

        // 5% of the FENG goes to DAO Fund which can burn it if needed
        uint256 _daoFundSharedAmount = 0;
        if (daoFundSharedPercent > 0) {
            _daoFundSharedAmount = _amount.mul(daoFundSharedPercent).div(10000);
            IERC20(feng).transfer(daoFund, _daoFundSharedAmount);
            emit DaoFundFunded(now, _daoFundSharedAmount);
        }

        // 5% of FENG goes to DEV fund to expand the protocol
        uint256 _devFundSharedAmount = 0;
        if (devFundSharedPercent > 0) {
            _devFundSharedAmount = _amount.mul(devFundSharedPercent).div(10000);
            IERC20(feng).transfer(devFund, _devFundSharedAmount);
            emit DevFundFunded(now, _devFundSharedAmount);
        }

        _amount = _amount.sub(_daoFundSharedAmount).sub(_devFundSharedAmount);

        IERC20(feng).safeApprove(masonry, 0);
        IERC20(feng).safeApprove(masonry, _amount);
        IMasonry(masonry).allocateSeigniorage(_amount);
        emit MasonryFunded(now, _amount);
    }

    function _calculateMaxSupplyExpansionPercent(uint256 _fengSupply) internal returns (uint256) {
        for (uint8 tierId = 8; tierId >= 0; --tierId) {
            if (_fengSupply >= supplyTiers[tierId]) {
                maxSupplyExpansionPercent = maxExpansionTiers[tierId];
                break;
            }
        }
        return maxSupplyExpansionPercent;
    }

    function allocateSeigniorage() external onlyOneBlock checkCondition checkEpoch checkOperator {
        _updateFengPrice();
        previousEpochFengPrice = getFengPrice();
        uint256 fengSupply = getFengCirculatingSupply().sub(seigniorageSaved);
        if (epoch < bootstrapEpochs) {
            // 28 first epochs with 3.0% expansion
            _sendToMasonry(fengSupply.mul(bootstrapSupplyExpansionPercent).div(10000));
        } else {
            if (previousEpochFengPrice > fengPriceCeiling) {
                // Expansion ($FENG Price > 1 $FTM): there is some seigniorage to be allocated
                uint256 bondSupply = IERC20(fbond).totalSupply();
                uint256 _percentage = previousEpochFengPrice.sub(fengPriceOne);
                uint256 _savedForBond;
                uint256 _savedForMasonry;
                uint256 _mse = _calculateMaxSupplyExpansionPercent(fengSupply).mul(1e14);
                if (_percentage > _mse) {
                    _percentage = _mse;
                }
                if (seigniorageSaved >= bondSupply.mul(bondDepletionFloorPercent).div(10000)) {
                    // saved enough to pay debt, mint as usual rate
                    _savedForMasonry = fengSupply.mul(_percentage).div(1e18);
                } else {
                    // have not saved enough to pay debt, mint more
                    uint256 _seigniorage = fengSupply.mul(_percentage).div(1e18);
                    _savedForMasonry = _seigniorage.mul(seigniorageExpansionFloorPercent).div(10000);
                    _savedForBond = _seigniorage.sub(_savedForMasonry);
                    if (mintingFactorForPayingDebt > 0) {
                        _savedForBond = _savedForBond.mul(mintingFactorForPayingDebt).div(10000);
                    }
                }
                if (_savedForMasonry > 0) {
                    _sendToMasonry(_savedForMasonry);
                }
                if (_savedForBond > 0) {
                    seigniorageSaved = seigniorageSaved.add(_savedForBond);
                    IBasisAsset(feng).mint(address(this), _savedForBond);
                    emit TreasuryFunded(now, _savedForBond);
                }
            }
        }
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        // do not allow to drain core tokens
        require(address(_token) != address(feng), "feng");
        require(address(_token) != address(fbond), "bond");
        require(address(_token) != address(sfeng), "share");
        _token.safeTransfer(_to, _amount);
    }

    function masonrySetOperator(address _operator) external onlyOperator {
        IMasonry(masonry).setOperator(_operator);
    }

    function masonrySetLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) external onlyOperator {
        IMasonry(masonry).setLockUp(_withdrawLockupEpochs, _rewardLockupEpochs);
    }

    function masonryAllocateSeigniorage(uint256 amount) external onlyOperator {
        IMasonry(masonry).allocateSeigniorage(amount);
    }

    function masonryGovernanceRecoverUnsupported(
        address _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        IMasonry(masonry).governanceRecoverUnsupported(_token, _amount, _to);
    }
}