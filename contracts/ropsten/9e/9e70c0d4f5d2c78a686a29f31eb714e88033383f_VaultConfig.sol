//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../interfaces/IRhoToken.sol";
import "../interfaces/IVaultConfig.sol";

contract VaultConfig is IVaultConfig, AccessControlEnumerableUpgradeable, PausableUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
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
        underlying = _addr;
        underlyingOne = 10**IERC20MetadataUpgradeable(underlying).decimals();
    }
    /* rho token */
    function _setRhoToken(address _addr) internal {
        rhoToken = _addr;
        rhoOne = 10**IRhoToken(rhoToken).decimals();
    }

    // calculates underlying reserve at upper bound based on a rho total supply
    function reserveUpperBound(uint256 tvl) external override view returns (uint256) {
        return ((tvl * reserveBoundary[1]) / 1e18);
    }

    // calculates underlying reserve at lower bound based on a rho total supply
    function reserveLowerBound(uint256 tvl) external override view returns (uint256) {
        return ((tvl * reserveBoundary[0]) / 1e18);
    }
    /* pause */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function addStrategy(string memory name, address strategy)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        strategies.push(Strategy(name, IRhoStrategy(strategy)));
        strategyAddrs.push(strategy);
        emit StrategyAdded(name, strategy);
    }

    function removeStrategy(address strategy) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        for (uint256 i = 0; i < strategies.length; i++) {
            Strategy storage s = strategies[i];
            if (address(s.target) == strategy) {
                require(i < strategies.length);

                // recall funds if there any from strategy
                try strategies[i].target.withdrawAllCashAvailable() {
                    require(strategies[i].target.updateBalanceOfUnderlying() == 0, "fund left in strategy");
                    strategies[i] = strategies[strategies.length - 1];
                    strategies.pop();
                    strategyAddrs[i] = strategyAddrs[strategyAddrs.length - 1];
                    strategyAddrs.pop();
                    emit StrategyRemoved(strategies[i].name, address(strategies[i].target));
                } catch Error(string memory reason) {
                    emit Log(reason);
                }
                return;
            }
        }
    }

    function isStrategyRegistered(address s) external view override returns (bool) {
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
}