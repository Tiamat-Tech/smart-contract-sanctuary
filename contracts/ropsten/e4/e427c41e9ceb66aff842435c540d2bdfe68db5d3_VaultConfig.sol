//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../interfaces/IRhoToken.sol";
import "../interfaces/IVaultConfig.sol";

contract VaultConfig is IVaultConfig, AccessControlEnumerableUpgradeable, PausableUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    address public override rhoToken;
    address public override underlying;
    uint256 public override mintingFee; // 18 decimal
    uint256 public override redeemFee; // 18 decimal
    uint256[2] public override reserveBoundary; // 18 decimal
    uint256 public override managementFee; // 18 decimal
    uint256 public override rewardCollectThreshold;
    uint256 public override rhoOne;
    uint256 public override underlyingOne;
    Strategy[] public strategies;
    address[] public strategyAddrs;

    /**
     * @notice Flurry Price Oracle to give price feed for native currency
     * For example, ETH on Ethereum, BNB on Binance Smart Chain...
     * Default base = underlying token, quote = native currency
     */
    address public override underlyingNativePriceOracle;

    function initialize(
        address _rhoAddr,
        address _underlyingAddr,
        address _udlyNativePriceOracleAddr,
        uint256 _mFee,
        uint256 _rFee,
        uint256 _mngtFee,
        uint256 _rLowerBound,
        uint256 _rUpperBound,
        uint256 _rewardCollectThreshold
    ) public initializer {
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        PausableUpgradeable.__Pausable_init_unchained();
        _setMintingFee(_mFee);
        _setRedeemFee(_rFee);
        _setManagementFee(_mngtFee);
        _setReserveBoundary(_rLowerBound, _rUpperBound);
        _setRhoToken(_rhoAddr);
        _setUnderlying(_underlyingAddr);
        _setUnderlyingNativePriceOracle(_udlyNativePriceOracleAddr);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRewardCollectThreshold(_rewardCollectThreshold);
    }

    function setUnderlyingNativePriceOracle(address addr) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _setUnderlyingNativePriceOracle(addr);
    }

    function _setUnderlyingNativePriceOracle(address addr) internal {
        require(addr != address(0), "Und-Native price oracle addrress is 0");
        underlyingNativePriceOracle = addr;
    }

    function setMintingFee(uint256 _feeInWei) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _setMintingFee(_feeInWei);
    }

    function _setMintingFee(uint256 _feeInWei) internal {
        mintingFee = _feeInWei;
    }

    /* redeem Fee */
    function setRedeemFee(uint256 _feeInWei) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _setRedeemFee(_feeInWei);
    }

    function _setRedeemFee(uint256 _feeInWei) internal {
        redeemFee = _feeInWei;
    }

    /* in underlying token */
    function setRewardCollectThreshold(uint256 _rewardCollectThreshold)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        _setRewardCollectThreshold(_rewardCollectThreshold);
    }

    function _setRewardCollectThreshold(uint256 _rewardCollectThreshold) internal {
        rewardCollectThreshold = _rewardCollectThreshold * underlyingOne;
    }

    function setManagementFee(uint256 _feeInWei) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _setManagementFee(_feeInWei);
    }

    function _setManagementFee(uint256 _feeInWei) internal {
        managementFee = _feeInWei;
    }

    /* alloc threshold */
    function setReserveBoundary(uint256 reserveLowerBound_, uint256 reserveUpperBound_)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        _setReserveBoundary(reserveLowerBound_, reserveUpperBound_);
    }

    function _setReserveBoundary(uint256 reserveLowerBound_, uint256 reserveUpperBound_) internal {
        reserveBoundary = [reserveLowerBound_, reserveUpperBound_];
    }

    /* underlying */
    function _setUnderlying(address _addr) internal {
        require(_addr != address(0), "underlying address is 0");
        underlying = _addr;
        underlyingOne = 10**IERC20MetadataUpgradeable(underlying).decimals();
    }

    /* rho token */
    function _setRhoToken(address _addr) internal {
        require(_addr != address(0), "rhoToken address is 0");
        rhoToken = _addr;
        rhoOne = 10**IRhoToken(rhoToken).decimals();
    }

    // calculates underlying reserve at upper bound based on a rho total supply
    function reserveUpperBound(uint256 tvl) public view override returns (uint256) {
        return ((tvl * reserveBoundary[1]) / 1e18);
    }

    // calculates underlying reserve at lower bound based on a rho total supply
    function reserveLowerBound(uint256 tvl) public view override returns (uint256) {
        return ((tvl * reserveBoundary[0]) / 1e18);
    }

    /* pause */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function supplyRate() external view override returns (uint256) {
        uint256 totalInterestPerYear;
        for (uint256 i = 0; i < strategies.length; i++) {
            totalInterestPerYear +=
                strategies[i].target.balanceOfUnderlying() *
                strategies[i].target.effectiveSupplyRate();
        }
        uint256 rebasingSupply = IRhoToken(rhoToken).unadjustedRebasingSupply(); // in 18
        if (rebasingSupply == 0) return type(uint256).max;
        return (totalInterestPerYear * rhoOne) / rebasingSupply / underlyingOne;
    }

    function addStrategy(string memory name, address strategy)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        require(strategy != address(0), "strategy address is 0");
        strategies.push(Strategy(name, IRhoStrategy(strategy)));
        strategyAddrs.push(strategy);
        emit StrategyAdded(name, strategy);
    }

    function removeStrategy(address strategy) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            IRhoStrategy target = strategies[i].target;
            if (address(target) == strategy) {
                // recall funds if there any from strategy
                try target.withdrawAllCashAvailable() {
                    require(target.updateBalanceOfUnderlying() == 0, "fund left in strategy");
                    emit StrategyRemoved(strategies[i].name, address(target));
                    strategies[i] = strategies[len - 1];
                    strategies.pop();
                    strategyAddrs[i] = strategyAddrs[strategyAddrs.length - 1];
                    strategyAddrs.pop();
                } catch Error(string memory reason) {
                    emit Log(reason);
                }
                return;
            }
        }
    }

    function isStrategyRegistered(address s) external view override returns (bool) {
        require(s != address(0), "strategy address is 0");
        for (uint256 i = 0; i < strategyAddrs.length; i++) {
            if (strategyAddrs[i] == s) return true;
        }
        return false;
    }

    function getStrategiesList() external view override returns (Strategy[] memory) {
        return strategies;
    }

    function getStrategiesListLength() external view override returns (uint256) {
        return strategies.length;
    }

    function updateStrategiesDetail(uint256 vaultUnderlyingBalance)
        external
        override
        onlyRole(VAULT_ROLE)
        returns (
            uint256[] memory,
            uint256[] memory,
            bool[] memory,
            uint256,
            uint256
        )
    {
        uint256 underlyingInvested = 0;
        uint256 underlyingDeployable = 0;

        bool[] memory locked = new bool[](strategies.length);
        uint256[] memory balance = new uint256[](strategies.length);
        uint256[] memory withdrawable = new uint256[](strategies.length);

        uint256 underlyingUninvested = vaultUnderlyingBalance;

        for (uint256 i = 0; i < strategies.length; i++) {
            balance[i] = strategies[i].target.updateBalanceOfUnderlying();
            withdrawable[i] = strategies[i].target.underlyingWithdrawable();
            underlyingInvested += balance[i];
            if (strategies[i].target.isLocked()) {
                locked[i] = true;
            } else {
                underlyingDeployable += withdrawable[i];
            }
        }

        uint256 tvl = underlyingUninvested + underlyingInvested;
        uint256 upperBound = reserveUpperBound(tvl);
        if (underlyingUninvested > upperBound) {
            uint256 lowerBound = reserveLowerBound(tvl);
            underlyingDeployable += underlyingUninvested - lowerBound;
        }

        // optimal strategy? worst strategy?
        uint256 optimalRate;
        uint256 optimalIndex;
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 rate;
            if (strategies[i].target.isLocked()) {
                // locked fund is not counted in underlyingDeployable
                rate = strategies[i].target.effectiveSupplyRate(underlyingDeployable, true);
            } else {
                // locked fund is counted in underlyingDeployable, offset the deployable by its own withdrawable
                rate = strategies[i].target.effectiveSupplyRate(underlyingDeployable - withdrawable[i], true);
            }
            if (rate > optimalRate) {
                optimalRate = rate;
                optimalIndex = i;
            }
        }
        return (balance, withdrawable, locked, optimalIndex, underlyingDeployable);
    }

    function checkStrategiesCollectReward() external view override returns (bool[] memory collectList) {
        bool[] memory _collectList = new bool[](strategies.length);
        for (uint256 i = 0; i < strategies.length; i++) {
            _collectList[i] = strategies[i].target.shouldCollectReward(rewardCollectThreshold);
        }
        return _collectList;
    }
}