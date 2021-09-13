//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IRhoToken.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IVaultConfig.sol";

contract Vault is IVault, AccessControlEnumerableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    bytes32 public constant REBASE_ROLE = keccak256("REBASE_ROLE");
    bytes32 public constant COLLECT_ROLE = keccak256("COLLECT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");
    IVaultConfig public override config;

    uint256 public feeInRho;

    function initialize(address config_) public initializer {
        require(config_ != address(0), "VaultConfig address is 0");
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        PausableUpgradeable.__Pausable_init_unchained();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        config = IVaultConfig(config_);
    }

    function rhoToken() public view returns (IRhoToken) {
        return IRhoToken(config.rhoToken());
    }

    function underlying() public view returns (IERC20MetadataUpgradeable) {
        return IERC20MetadataUpgradeable(config.underlying());
    }

    function reserveBoundary(uint256 i) external view returns (uint256) {
        return config.reserveBoundary(i);
    }

    function rhoOne() internal view returns (uint256) {
        return config.rhoOne();
    }

    function underlyingOne() internal view returns (uint256) {
        return config.underlyingOne();
    }

    function supportsAsset(address _asset) external view override returns (bool) {
        return _asset == address(underlying());
    }

    function reserve() external view override returns (uint256) {
        return underlying().balanceOf(address(this));
    }

    function getStrategiesList() public view override returns (IVaultConfig.Strategy[] memory) {
        return config.getStrategiesList();
    }

    function getStrategiesListLength() public view override returns (uint256) {
        return config.getStrategiesListLength();
    }

    /* distribution */
    function mint(uint256 amount) external override whenNotPaused nonReentrant {
        underlying().safeTransferFrom(_msgSender(), address(this), amount);
        uint256 amountInRho = (amount * rhoOne()) / underlyingOne();
        rhoToken().mint(_msgSender(), amountInRho);
    }

    function redeem(uint256 amountInRho) external override whenNotPaused nonReentrant {
        require(rhoToken().balanceOf(_msgSender()) >= amountInRho, "redeem amount exceeds rhoToken balance");

        uint256 amountInUnderlying = (amountInRho * underlyingOne()) / rhoOne();
        uint256 reserveBalance = underlying().balanceOf(address(this));
        if (reserveBalance >= amountInUnderlying) {
            rhoToken().burn(_msgSender(), amountInRho);
            underlying().safeTransfer(_msgSender(), amountInUnderlying);
            return;
        }

        IVaultConfig.Strategy[] memory strategies = config.getStrategiesList();

        // reserveBalance hit zero, unallocate to replenish reserveBalance to lower bound
        (uint256[] memory balance, uint256[] memory withdrawable, , , ) =
            config.updateStrategiesDetail(underlying().balanceOf(address(this)));

        uint256 totalUnderlyingToBe = (rhoToken().totalSupply() * underlyingOne()) / rhoOne() - amountInUnderlying;
        uint256 amountToWithdraw = amountInUnderlying - reserveBalance + config.reserveLowerBound(totalUnderlyingToBe); // in underlying

        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 stgTarget = strategies[i].target.switchingLockTarget();
            if (withdrawable[i] > amountToWithdraw) {
                strategies[i].target.withdrawUnderlying(amountToWithdraw);
                if (stgTarget > withdrawable[i]) {
                    strategies[i].target.switchingLock(stgTarget - withdrawable[i], false);
                } else {
                    strategies[i].target.switchingLock(0, false);
                }
                break;
            } else {
                if (balance[i] == 0) {
                    continue;
                }
                if (stgTarget > withdrawable[i]) {
                    strategies[i].target.switchingLock(stgTarget - withdrawable[i], false);
                } else {
                    strategies[i].target.switchingLock(0, false);
                }
                amountToWithdraw -= withdrawable[i];
                strategies[i].target.withdrawAllCashAvailable();
            }
        }
        rhoToken().burn(_msgSender(), amountInRho);
        underlying().safeTransfer(_msgSender(), amountInUnderlying);
    }

    /* asset management */
    function rebase() external override onlyRole(REBASE_ROLE) whenNotPaused nonReentrant {
        IVaultConfig.Strategy[] memory strategies = config.getStrategiesList();

        uint256 originalTvlInRho = rhoToken().totalSupply();
        if (originalTvlInRho == 0) {
            return;
        }
        // rebalance fund
        _rebalance();
        uint256 underlyingInvested;
        for (uint256 i = 0; i < strategies.length; i++) {
            underlyingInvested += strategies[i].target.updateBalanceOfUnderlying();
        }
        uint256 underlyingUninvested = underlying().balanceOf(address(this));
        uint256 currentTvlInUnderlying = underlyingUninvested + underlyingInvested;
        uint256 currentTvlInRho = (currentTvlInUnderlying * rhoOne()) / underlyingOne();
        uint256 rhoRebasing = rhoToken().unadjustedRebasingSupply();
        uint256 rhoNonRebasing = rhoToken().nonRebasingSupply();

        if (rhoRebasing < 1e18) {
            // in this case, rhoNonRebasing = rho TotalSupply
            uint256 originalTvlInUnderlying = (originalTvlInRho * underlyingOne()) / rhoOne();
            if (currentTvlInUnderlying > originalTvlInUnderlying) {
                // invested accrued interest
                // all the interest goes to the fee pool since no one is entitled for the interest.
                uint256 feeToMint = ((currentTvlInUnderlying - originalTvlInUnderlying) * rhoOne()) / underlyingOne();
                rhoToken().mint(address(this), feeToMint);
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
            rhoToken().setMultiplier(_newM);
            return;
        }
        uint256 fee36 = (currentTvlInRho - originalTvlInRho) * config.managementFee();
        uint256 fee18 = fee36 / 1e18;
        if (fee18 > 0) {
            // mint vault's fee18
            rhoToken().mint(address(this), fee18);
            feeInRho += fee18;
        }
        uint256 newM = ((currentTvlInRho * 1e18 - rhoNonRebasing * 1e18 - fee36) * 1e18) / rhoRebasing;
        rhoToken().setMultiplier(newM);
    }

    function rebalance() external override onlyRole(REBASE_ROLE) whenNotPaused nonReentrant {
        _rebalance();
    }

    function _rebalance() internal {
        IVaultConfig.Strategy[] memory strategies = config.getStrategiesList();
        uint256 gasused;
        (
            uint256[] memory balance,
            uint256[] memory withdrawable,
            bool[] memory locked,
            uint256 optimalIndex,
            uint256 underlyingDeployable
        ) = config.updateStrategiesDetail(underlying().balanceOf(address(this)));
        for (uint256 i = 0; i < strategies.length; i++) {
            if (balance[i] == 0) continue;
            if (locked[i]) continue;
            if (optimalIndex == i) continue;
            // withdraw
            uint256 gas0 = gasleft();
            strategies[i].target.withdrawAllCashAvailable();
            uint256 stgTarget = strategies[i].target.switchingLockTarget();
            if (stgTarget > withdrawable[i]) {
                strategies[i].target.switchingLock(stgTarget - withdrawable[i], false);
            } else {
                strategies[i].target.switchingLock(0, false);
            }
            gasused += gas0 - gasleft();
        }

        uint256 deployAmount;
        if (locked[optimalIndex]) {
            // locked fund is not counted in underlyingDeployable
            deployAmount = underlyingDeployable;
        } else {
            // locked fund is counted in underlyingDeployable, offset the deployable by its own balance
            deployAmount = underlyingDeployable - withdrawable[optimalIndex];
        }
        if (deployAmount == 0) {
            return;
        }
        uint256 gas1 = gasleft();
        underlying().safeTransfer(address(strategies[optimalIndex].target), deployAmount);
        strategies[optimalIndex].target.deploy(deployAmount);
        gasused += gas1 - gasleft();

        uint256 nativePrice =
            IPriceOracle(config.underlyingNativePriceOracle()).priceByQuoteSymbol(address(underlying()));
        uint256 switchingCost = (gasused * tx.gasprice * nativePrice) / 1e18;
        uint256 switchingCostInUnderlying = (switchingCost * underlyingOne()) / 1e18;
        strategies[optimalIndex].target.switchingLock(
            deployAmount + switchingCostInUnderlying + strategies[optimalIndex].target.switchingLockTarget(),
            true
        );
    }

    // withdraw random token transfer into this contract
    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) whenNotPaused {
        require(token != address(0), "token address is 0");
        require(token != address(underlying()) && token != address(rhoToken()), "!safe");
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }

    function sweepRhoTokenContractERC20Token(address token, address to)
        external
        override
        onlyRole(SWEEPER_ROLE)
        whenNotPaused
    {
        rhoToken().sweepERC20Token(token, to);
    }

    function supplyRate() external view override returns (uint256) {
        return config.supplyRate();
    }

    function collectStrategiesRewardTokenByIndex(uint16[] memory collectList)
        external
        override
        onlyRole(COLLECT_ROLE)
        whenNotPaused
        nonReentrant
        returns (bool[] memory sold)
    {
        sold = new bool[](collectList.length);
        IVaultConfig.Strategy[] memory strategies = config.getStrategiesList();
        for (uint256 i = 0; i < collectList.length; i++) {
            try strategies[collectList[i]].target.collectRewardToken() {
                sold[i] = true;
            } catch Error(string memory reason) {
                emit CollectRewardError(msg.sender, address(strategies[collectList[i]].target), reason);
                continue;
            } catch {
                emit CollectRewardUnknownError(msg.sender, address(strategies[collectList[i]].target));
                continue;
            }
        }
    }

    function checkStrategiesCollectReward() external view override returns (bool[] memory collectList) {
        return config.checkStrategiesCollectReward();
    }

    function withdrawFees(uint256 amount, address to) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(feeInRho >= amount, "withdraw fees > vault fees balance");
        rhoToken().transfer(to, amount);
    }

    /* pause */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}