//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "../interfaces/IVault.sol";
import "../interfaces/IRhoStrategy.sol";
import "../interfaces/IRhoToken.sol";
import "../interfaces/chainlink/AggregatorV3Interface.sol";
import "../libraries/flurry.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract Vault is IVault, PausableUpgradeable, AccessControlEnumerableUpgradeable {
    using Flurry for *;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    bytes32 public constant REBASE_ROLE = keccak256("REBASE_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");

    uint256 private constant MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    uint256 private _rhoOne;
    uint256 private _underlyingOne;

    IRhoToken public override rhoToken;
    IERC20MetadataUpgradeable public override underlying;

    /**
     * @notice Chainlink aggregator to give price feed for native currency
     * For example, ETH on Ethereum, BNB on Binance Smart Chain...
     */
    AggregatorV3Interface public override nativePriceFeed;
    // 18 decimal
    uint256 public override mintingFee;
    // 18 decimal
    uint256 public override redeemFee;
    // 18 decimal
    uint256[2] public override reserveBoundary;
    uint256 public override managementFee;

    Strategy[] public strategies;
    address[] public strategyAddrs;

    uint256 public feeInRho;

    function initialize(
        address _rhoAddr,
        address _underlyingAddr,
        address _udlyNativePriceFeedAddr,
        uint256 _mFee,
        uint256 _rFee,
        uint256 _mngtFee,
        uint256 _rLowerBound,
        uint256 _rUpperBound
    ) public initializer {
        PausableUpgradeable.__Pausable_init();
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        _setMintingFee(_mFee);
        _setRedeemFee(_rFee);
        _setManagementFee(_mngtFee);
        _setReserveBoundary(_rLowerBound, _rUpperBound);
        _setRhoToken(_rhoAddr);
        _setUnderlying(_underlyingAddr);
        _setNativePriceFeed(_udlyNativePriceFeedAddr);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setNativePriceFeed(address addr) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _setNativePriceFeed(addr);
    }

    function _setNativePriceFeed(address addr) internal {
        nativePriceFeed = AggregatorV3Interface(addr);
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
        underlying = IERC20MetadataUpgradeable(_addr);
        _underlyingOne = 10**underlying.decimals();
    }

    function supportsAsset(address _asset) external view override returns (bool) {
        if (_asset == address(underlying)) {
            return true;
        }
        return false;
    }

    function reserve() external view override returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    /* rho token */
    function _setRhoToken(address _addr) internal {
        rhoToken = RhoToken(_addr);
        _rhoOne = 10**rhoToken.decimals();
    }

    /* distribution */
    function mint(uint256 amount) external override whenNotPaused {
        underlying.safeTransferFrom(_msgSender(), address(this), amount);
        uint256 amountInRho = (amount * _rhoOne) / _underlyingOne;
        rhoToken.mint(_msgSender(), amountInRho);
        return;
    }

    function redeem(uint256 amountInRho) external override whenNotPaused {
        uint256 amountInUnderlying = (amountInRho * _underlyingOne) / _rhoOne;
        // uint256 residue = amountInRho - amountInUnderlying * _rhoOne / _underlyingOne ;
        require(rhoToken.balanceOf(_msgSender()) > amountInRho, "");

        uint256 reserveBalance = underlying.balanceOf(address(this));

        if (reserveBalance >= amountInUnderlying) {
            rhoToken.burn(_msgSender(), amountInRho);
            // if (residue > 0) {
            //     // gas ? does it worth?
            //     _mintResidue(residue);
            // }
            underlying.safeTransfer(_msgSender(), amountInUnderlying);
            return;
        }
        // reserveBalance hit zero, unallocate to replenish reserveBalance to lower bound
        (uint256[] memory balance, bool[] memory locked, , ) = _updateStrategiesDetail();

        uint256 totalUnderlyingToBe = (rhoToken.totalSupply() * _underlyingOne) / _rhoOne - amountInUnderlying;

        uint256 amountToWithdraw = amountInUnderlying - reserveBalance + _calcReserveLowerBound(totalUnderlyingToBe); // in underlying

        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].enabled) continue;
            if (balance[i] > amountToWithdraw) {
                _withdraw(amountToWithdraw, i);
                if (locked[i]) {
                    strategies[i].target.switchingLock(strategies[i].target.switchingLockTarget() - amountToWithdraw);
                }
                break;
            } else {
                if (balance[i] == 0) {
                    continue;
                }
                _withdrawAll(i);
                if (locked[i]) {
                    strategies[i].target.switchingLock(strategies[i].target.switchingLockTarget() - balance[i]);
                }
                amountToWithdraw -= balance[i];
            }
        }
        rhoToken.burn(_msgSender(), amountInRho);
        underlying.safeTransfer(_msgSender(), amountInUnderlying);
    }

    // function _mintResidue(uint256 residue) internal {
    //     feeInRho += residue;
    //     rhoToken.mint(address(this), residue);
    // }
    /* asset management */
    function rebase() external override onlyRole(REBASE_ROLE) whenNotPaused {
        uint256 originalTvlInRho = rhoToken.totalSupply();
        if (originalTvlInRho == 0) {
            return;
        }
        // rebalance fund
        _rebalance();
        uint256 underlyingInvested = _getUnderlyingInvested();
        uint256 underlyingUninvested = underlying.balanceOf(address(this));
        uint256 currentTvlInUnderlying = underlyingUninvested + underlyingInvested;
        uint256 currentTvlInRho = (currentTvlInUnderlying * _rhoOne) / _underlyingOne;
        uint256 rhoRebasing = rhoToken.unadjustedRebasingSupply();
        uint256 rhoNonRebasing = rhoToken.nonRebasingSupply();

        if (rhoRebasing == 0) {
            // in this case, rhoNonRebasing = rho TotalSupply
            uint256 originalTvlInUnderlying = (originalTvlInRho * _underlyingOne) / _rhoOne;
            if (currentTvlInUnderlying > originalTvlInUnderlying) {
                // invested accrued interest
                // all the interest goes to the fee pool since no one is entitled for the interest.
                uint256 feeToMint = ((currentTvlInUnderlying - originalTvlInUnderlying) * _rhoOne) / _underlyingOne;
                rhoToken.mint(address(this), feeToMint);
                feeInRho += feeToMint;
            }
            return;
        }

        // from this point forward, rhoRebasing > 0
        if (currentTvlInRho == originalTvlInRho) {
            // no fees charged, multiplier does not change
            return;
        }
        if (currentTvlInRho < originalTvlInRho) {
            // this happens when fund is initially deployed to compound and get balance of underlying right away
            // strategy losing money, no fees will be charged
            uint256 _newM = ((currentTvlInRho - rhoNonRebasing) * 1e36) / rhoRebasing;
            rhoToken.setMultiplier(_newM);
            return;
        }
        uint256 fee36 = (currentTvlInRho - originalTvlInRho) * managementFee;
        uint256 fee18 = fee36 / 1e18;
        if (fee18 > 0) {
            // mint vault's fee18
            rhoToken.mint(address(this), fee18);
            feeInRho += fee18;
        }
        uint256 newM = ((currentTvlInRho * 1e18 - rhoNonRebasing * 1e18 - fee36) * 1e18) / rhoRebasing;
        rhoToken.setMultiplier(newM);
    }

    function rebalance() external override onlyRole(REBASE_ROLE) whenNotPaused {
        _rebalance();
    }

    function _rebalance() internal {
        _allInAllOut();
    }

    function _updateStrategiesDetail()
        internal
        returns (
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

        uint256 underlyingUninvested = underlying.balanceOf(address(this));

        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].enabled) continue;
            balance[i] = strategies[i].target.updateBalanceOfUnderlying();
            underlyingInvested += balance[i];
            if (strategies[i].target.isLocked()) {
                locked[i] = true;
            } else {
                underlyingDeployable += balance[i];
            }
        }

        uint256 tvl = underlyingUninvested + underlyingInvested;
        uint256 upperBound = _calcReserveUpperBound(tvl);
        if (underlyingUninvested > upperBound) {
            uint256 lowerBound = _calcReserveLowerBound(tvl);
            underlyingDeployable += underlyingUninvested - lowerBound;
        }

        // optimal strategy? worst strategy?

        uint256 optimalRate = 0;
        uint256 optimalIndex = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].enabled) continue;
            uint256 rate;
            if (strategies[i].target.isLocked()) {
                // locked fund is not counted in underlyingDeployable
                rate = strategies[i].target.effectiveSupplyRate(underlyingDeployable, true);
            } else {
                // locked fund is counted in underlyingDeployable, offset the deployable by its own balance
                rate = strategies[i].target.effectiveSupplyRate(underlyingDeployable - balance[i], true);
            }
            if (rate > optimalRate) {
                optimalRate = rate;
                optimalIndex = i;
            }
        }
        return (balance, locked, optimalIndex, underlyingDeployable);
    }

    function _allInAllOut() internal {
        uint256 gasused = 0;
        (uint256[] memory balance, bool[] memory locked, uint256 optimalIndex, uint256 underlyingDeployable) =
            _updateStrategiesDetail();

        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].enabled) continue;
            if (balance[i] == 0) continue;
            if (locked[i]) continue;
            // withdraw
            uint256 gas0 = gasleft();
            _withdrawAll(i);
            gasused += gas0 - gasleft();
        }

        uint256 deployAmount;
        if (locked[optimalIndex]) {
            // locked fund is not counted in underlyingDeployable
            deployAmount = underlyingDeployable;
        } else {
            // locked fund is counted in underlyingDeployable, offset the deployable by its own balance
            deployAmount = underlyingDeployable - balance[optimalIndex];
        }
        if (deployAmount == 0) {
            return;
        }
        uint256 gas1 = gasleft();
        _deploy(deployAmount, optimalIndex);
        gasused += gas1 - gasleft();
        uint256 nativePrice = (10**nativePriceFeed.decimals() * 1e18) / Flurry.getPriceFromChainlink(nativePriceFeed);
        uint256 switchingCost = Flurry.calculateGasFee(nativePrice, gasused); // in 18
        uint256 switchingCostInUnderlying = (switchingCost * _underlyingOne) / 1e18;
        uint256 newLockTarget = 0;
        if (locked[optimalIndex]) {
            newLockTarget =
                deployAmount +
                switchingCostInUnderlying +
                strategies[optimalIndex].target.switchingLockTarget();
        } else {
            newLockTarget = deployAmount + switchingCostInUnderlying;
        }
        strategies[optimalIndex].target.switchingLock(newLockTarget);
    }

    function _getUnderlyingInvested() internal returns (uint256) {
        uint256 underlyingInvested;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].enabled) continue;
            uint256 balance = strategies[i].target.updateBalanceOfUnderlying();
            underlyingInvested += balance;
        }
        return underlyingInvested;
    }

    // calculates underlying reserve at upper bound based on a rho total supply
    function _calcReserveUpperBound(uint256 tvl) internal view returns (uint256) {
        return ((tvl * reserveBoundary[1]) / 1e18);
    }

    // calculates underlying reserve at lower bound based on a rho total supply
    function _calcReserveLowerBound(uint256 tvl) internal view returns (uint256) {
        return ((tvl * reserveBoundary[0]) / 1e18);
    }

    function _withdraw(uint256 amount, uint256 from) internal {
        strategies[from].target.withdrawUnderlying(amount);
    }

    function _withdrawAll(uint256 from) internal {
        strategies[from].target.withdrawAll();
    }

    function _deploy(uint256 amount, uint256 to) internal {
        underlying.safeTransfer(address(strategies[to].target), amount);
        strategies[to].target.deploy(amount);
    }

    function addStrategy(
        string memory name,
        address s,
        bool enabled
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        strategies.push(Strategy(name, IRhoStrategy(s), enabled));
        strategyAddrs.push(s);
    }

    function isStrategyRegistered(address s) external view override returns (bool) {
        for (uint256 i = 0; i < strategyAddrs.length; i++) {
            if (strategyAddrs[i] == s) return true;
        }
        return false;
    }

    function disableStrategy(uint256 index) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        strategies[index].enabled = false;
    }

    function enableStrategy(uint256 index) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        strategies[index].enabled = true;
    }

    /* pause */
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    // withdraw random token transfer into this contract
    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) whenNotPaused {
        require(token != address(underlying), "!safe");
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }

    function sweepRhoTokenContractERC20Token(address token, address to)
        external
        override
        onlyRole(SWEEPER_ROLE)
        whenNotPaused
    {
        rhoToken.sweepERC20Token(token, to);
    }

    function supplyRate() external view returns (uint256) {
        // uint256 totalInvested = 0;
        uint256 totalInterestPerYear = 0;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].enabled) continue;
            totalInterestPerYear +=
                strategies[i].target.balanceOfUnderlying() *
                strategies[i].target.effectiveSupplyRate();
        }
        uint256 rebasingSupply = rhoToken.unadjustedRebasingSupply(); // in 18
        if (rebasingSupply == 0) {
            return MAX_UINT256;
        }
        uint256 result = (totalInterestPerYear * _rhoOne) / rebasingSupply / _underlyingOne;
        return result;
    }

    function getStrategiesList() external view returns (Strategy[] memory) {
        return strategies;
    }
}