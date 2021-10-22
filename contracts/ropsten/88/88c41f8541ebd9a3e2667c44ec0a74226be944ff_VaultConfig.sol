//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IRhoToken.sol";
import "../interfaces/IVaultConfig.sol";
import "../interfaces/IHorizon.sol";
import "../interfaces/IBridge.sol";
import "../interfaces/IRedemption.sol";
import "hardhat/console.sol";

contract VaultConfig is IVaultConfig, AccessControlEnumerableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    // v2
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


    // v3
    IHorizon public override horizon;
    IBridge public override underlyingBridge;
    IRedemption public override crossChainRedemption;
    IVault public override vault;
    bytes32 public constant COLLECT_ROLE = keccak256("COLLECT_ROLE");
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");

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

    function setUnderlyingBridge(address addr) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        underlyingBridge = IBridge(addr);
    }
    function setCrossChainRedemption(address addr) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        crossChainRedemption = IRedemption(addr);
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

    function removeStrategy(address strategy) external override onlyRole(VAULT_ROLE) whenNotPaused {
        _removeStrategy(strategy);
    }

    function _removeStrategy(address strategy) internal {
        uint256 len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            IRhoStrategy target = strategies[i].target;
            if (address(target) == strategy) {
                strategies[i] = strategies[len - 1];
                strategies.pop();
                strategyAddrs[i] = strategyAddrs[strategyAddrs.length - 1];
                strategyAddrs.pop();
                emit StrategyRemoved(strategies[i].name, address(target));
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
    function listWithdrawable() external view override returns(uint256[] memory r) {
        uint len = strategies.length;
        r = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            r[i] = strategies[i].target.underlyingWithdrawable();
        }
    }

    function checkStrategiesCollectReward() external view override returns (bool[] memory collectList) {
        uint len = strategies.length;
        bool[] memory _collectList = new bool[](len);
        for (uint256 i = 0; i < len; i++) {
            _collectList[i] = strategies[i].target.shouldCollectReward(rewardCollectThreshold);
        }
        return _collectList;
    }

    function setHorizon(address h) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        horizon = IHorizon(h);
    }

    function retireStrategy(address strategy) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(strategy != address(0), "strategy address is 0");
        IRhoStrategy target = IRhoStrategy(strategy);

        // TODO - claim and sell bonus tokens, if any

        // recall funds if there any from strategy
        try target.withdrawAllCashAvailable(address(vault)) {
            require(target.updateBalanceOfUnderlying() == 0, "fund left in strategy");
            _removeStrategy(strategy);
        } catch Error(string memory reason) {
            emit Log(reason);
        }
    }
    function setVault(address vault_) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        vault = IVault(vault_);
    }
    function collectStrategiesRewardTokenByIndex(uint16[] memory collectList)
        external
        override
        onlyRole(COLLECT_ROLE)
        whenNotPaused
        nonReentrant
        returns (bool[] memory sold)
    {
        uint len = collectList.length;
        sold = new bool[](len);
        IVaultConfig.Strategy[] memory _strategies = strategies;
        for (uint256 i = 0; i < len; i++) {
            IRhoStrategy target = _strategies[collectList[i]].target;
            try target.collectRewardToken(address(vault)) {
                sold[i] = true;
            } catch Error(string memory reason) {
                emit CollectRewardError(msg.sender, address(target), reason);
                continue;
            } catch {
                emit CollectRewardUnknownError(msg.sender, address(target));
                continue;
            }
        }
    }
    // move to vaultConfig
    function sweepRhoTokenContractERC20Token(address token, address to)
        external
        override
        onlyRole(SWEEPER_ROLE)
        whenNotPaused
    {
        IRhoToken(rhoToken).sweepERC20Token(token, to);
    }

}