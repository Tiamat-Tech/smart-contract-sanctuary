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
import "../interfaces/IHorizon.sol";
import "hardhat/console.sol";

contract Vault is IVault, AccessControlEnumerableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
    // v2 storage
    bytes32 public constant REBASE_ROLE = keccak256("REBASE_ROLE");
    bytes32 public constant COLLECT_ROLE = keccak256("COLLECT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");
    IVaultConfig public override config;
    uint256 public feeInRho;

    // v3 storage
    bytes32 public constant HORIZON_ROLE = keccak256("HORIZON_ROLE");

    function initialize(address config_) public initializer {
        require(config_ != address(0), "VaultConfig address is 0");
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        PausableUpgradeable.__Pausable_init_unchained();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        config = IVaultConfig(config_);
    }
    function rhoToken() public view override returns (IRhoToken) {
        return IRhoToken(config.rhoToken());
    }

    function underlying() public view returns (IERC20MetadataUpgradeable) {
        return IERC20MetadataUpgradeable(config.underlying());
    }

    function reserveBoundary(uint256 i) external view returns (uint256) {
        return config.reserveBoundary(i);
    }

    function supportsAsset(address _asset) external view override returns (bool) {
        return _asset == config.underlying();
    }

    function reserve() external view override returns (uint256) {
        return underlying().balanceOf(address(this));
    }

    // function _getUnderlyingBridge() internal view returns(IBridge) {
    //     return config.underlyingBridge();
    // }
    function _crossChainRedemption() internal view returns(IRedemption) {
        return config.crossChainRedemption();
    }

    /* distribution */
    function mint(uint256 amount) external override whenNotPaused nonReentrant {
        underlying().safeTransferFrom(_msgSender(), address(this), amount);
        uint256 amountInRho = (amount * config.rhoOne()) / config.underlyingOne();
        rhoToken().mint(_msgSender(), amountInRho);
    }

    function redeem(uint256 amountInRho) external override whenNotPaused nonReentrant {
        require(rhoToken().balanceOf(_msgSender()) >= amountInRho, "amount exceeds balance");
        uint256 amountInUnderlying = (amountInRho * config.underlyingOne()) / config.rhoOne();
        uint256 reserveBalance = underlying().balanceOf(address(this));
        if (reserveBalance >= amountInUnderlying) {
            rhoToken().burn(_msgSender(), amountInRho);
            underlying().safeTransfer(_msgSender(), amountInUnderlying);
            return;
        }

        IVaultConfig.Strategy[] memory strategies = config.getStrategiesList();

        // reserveBalance hit zero, unallocate to replenish reserveBalance to lower bound
        uint256[] memory withdrawable = config.listWithdrawable();
        uint256 totalUnderlyingToBe = (rhoToken().totalSupply() * config.underlyingOne()) / config.rhoOne() - amountInUnderlying;
        uint256 reserveToBe = config.reserveLowerBound(totalUnderlyingToBe);
        uint256 amountToWithdraw = amountInUnderlying - reserveBalance + reserveToBe; // in underlying
        uint len = strategies.length;
        for (uint256 i = 0; i < len; i++) {
            IRhoStrategy stg = strategies[i].target;
            uint256 stgTarget = stg.switchingLockTarget();
            if (withdrawable[i] > amountToWithdraw) {
                stg.withdrawUnderlying(amountToWithdraw);
                if (stgTarget > withdrawable[i]) {
                    stg.switchingLock(stgTarget - withdrawable[i], false);
                } else {
                    stg.switchingLock(0, false);
                }
                break;
            } else {
                if (withdrawable[i] == 0) {
                    continue;
                }
                uint256 withdrawn = stg.withdrawAllCashAvailable(address(this));
                if (stgTarget > withdrawn) {
                    stg.switchingLock(stgTarget - withdrawn, false);
                } else {
                    stg.switchingLock(0, false);
                }
                amountToWithdraw -= withdrawn;
            }
        }
        if (amountToWithdraw == 0) {
            rhoToken().burn(_msgSender(), amountInRho);
            underlying().safeTransfer(_msgSender(), amountInUnderlying);
            return;
        }
        // from this point forward, amountToWithdraw = outstanding amount
        uint256 balance = underlying().balanceOf(address(this));
        if (balance > reserveToBe) {
            // more than enough balance
            rhoToken().burn(_msgSender(), (balance - reserveToBe) * config.rhoOne() / config.underlyingOne());
            underlying().safeTransfer(_msgSender(), balance - reserveToBe);
            _crossChainRedemption().mint(
                _msgSender(),
                amountInRho - (balance - reserveToBe) * config.rhoOne() / config.underlyingOne()
            );
            return;
        }
        _crossChainRedemption().mint(
            _msgSender(),
            amountInRho
        );
        return;

    }

    /* asset management */

    function _mintFee(uint256 amountInRho) internal {
        rhoToken().mint(address(this), amountInRho);
        feeInRho += amountInRho;
    }
    function receiveDividend(int256 amountInRho) external override onlyRole(HORIZON_ROLE) {
        console.logInt(amountInRho);
        if ( rhoToken().unadjustedRebasingSupply() < 1e18) {
            if (amountInRho > 0) {
                // mint all profit as fee when unadjustedRebasingSupply less than 1e18
                // this is to avoid multiplier going up exponentially
                _mintFee(uint256(amountInRho));
                return;
            } else {
                // losses will be realized in the next rebase when unadjustedRebasingSupply greater than 1e18
                // this is to avoid multiplier going up exponentially
                return;
            }

        }
        console.log("receiveDividend");
        uint256 fee = 0;
        // mintFee amountInRho fee when amountInRho > 0
        if (amountInRho > 0) {
            console.logInt(amountInRho);
            fee = uint256(amountInRho) * IVaultConfig(config).managementFee() / 1e18;
            _mintFee(fee);
        }
        console.log("receiveDividend", fee);
        (uint256 oldM, ) = rhoToken().getMultiplier();
        console.log("receiveDividend", oldM);
        int256 newM = int256(oldM) + ((amountInRho - int256(fee)) * 1e36 / int256(rhoToken().unadjustedRebasingSupply()));
        console.logInt(newM);
        require(newM >= 0, "new multiplier lt 0");
        console.log("receiveDividend");
        rhoToken().setMultiplier(uint256(newM));
        console.log("receiveDividend");
    }

    function rebalance(IHorizonConfig.OptimalStrategy calldata s, uint256 upfrontCost) external override onlyRole(HORIZON_ROLE) whenNotPaused nonReentrant returns(uint256, uint256) {
        uint256 initialgas = gasleft();
        IVaultConfig.Strategy[] memory strategies = config.getStrategiesList();
        int256 excess;
        // withdraw
        if (s.chainId == block.chainid) {
            require(bytes12(keccak256(abi.encodePacked(s.optimalIndex, address(strategies[s.optimalIndex].target)))) == s.checkByte, "check byte fail");
            // optimal strategy is local
            _withdrawAllExcept(strategies, s.optimalIndex);
            excess = _excessReserve();
            if (excess <= 0) {
                return (0, 0);
            }
            _deployLocal(strategies[s.optimalIndex].target, uint256(excess), initialgas, upfrontCost);
            return (0, 0);
        }
        // optimal strategy is beyond local
        _withdrawAll(strategies);
        excess = _excessReserve();
        if (excess <= 0) {
            return (0, 0);
        }
        return (uint256(excess), _deployCrossChain(s, uint256(excess), initialgas));
    }

    function deployExcessReserve(IHorizonConfig.OptimalStrategy calldata s, uint256 upfrontCost) external override onlyRole(HORIZON_ROLE) whenNotPaused nonReentrant {
        IVaultConfig.Strategy[] memory strategies = config.getStrategiesList();
        if (s.chainId == block.chainid) {
            require(bytes12(keccak256(abi.encodePacked(s.optimalIndex, address(strategies[s.optimalIndex].target)))) == s.checkByte, "check byte fail");
            // optimal strategy is local
            int256 excessReserve = _excessReserve();
            if (excessReserve <= 0) {
                return;
            }
            _deployLocal(
                strategies[s.optimalIndex].target,
                uint256(excessReserve),
                gasleft(),
                upfrontCost
            );
            return;
        }
    }

    function _deployLocal(IRhoStrategy optimal, uint256 amount, uint256 initialgas, uint256 upfrontCost) internal returns (uint256 cost){
        underlying().safeTransfer(address(optimal), amount);
        optimal.deploy(amount);
        uint originalTarget = optimal.switchingLockTarget();
        cost = _switchingCostInUnderlying(initialgas - gasleft()) + upfrontCost;
        optimal.switchingLock(
            originalTarget + amount + cost,
            true
        );
    }

    function _deployCrossChain(IHorizonConfig.OptimalStrategy calldata s, uint256 amount, uint256 initialgas) internal returns (uint256 cost){
        IBridge b = config.underlyingBridge();
        if (address(b) == address(0)) return 0;
        underlying().safeApprove(address(b), amount);
        b.swapOut(underlying(), s.vaultAddr, amount, s.chainId);
        return _switchingCostInUnderlying(initialgas - gasleft());
    }

    function _withdrawAll(IVaultConfig.Strategy[] memory strategies) internal {
        _withdrawAllExcept(strategies, type(uint256).max);
    }

    function _withdrawAllExcept(IVaultConfig.Strategy[] memory strategies, uint256 index) internal {
        for (uint256 i = 0; i < strategies.length; i++) {
            IRhoStrategy target = strategies[i].target;
            if (target.balanceOfUnderlying() == 0) continue;
            if (target.isLocked()) continue;
            if (index == i) {
                continue;
            }
            // withdraw
            uint256 withdrawn = target.withdrawAllCashAvailable(address(this));
            uint256 stgTarget = target.switchingLockTarget();
            if (stgTarget > withdrawn) {
                target.switchingLock(stgTarget - withdrawn, false);
            } else {
                target.switchingLock(0, false);
            }
        }
    }
    function _excessReserve() internal view returns(int256) {
        return int256(underlying().balanceOf(address(this))) - int256(config.reserveLowerBound(rhoToken().totalSupply() * config.underlyingOne() / config.rhoOne()));
    }
    function _switchingCostInUnderlying(uint256 gasused) internal view returns (uint256) {
        IPriceOracle p = IPriceOracle(config.underlyingNativePriceOracle());
        return (
            gasused * tx.gasprice // in wei
            * p.priceByQuoteSymbol(config.underlying()) // price of 1 ether in p.decimals()
            * config.underlyingOne()
            / 1e18 / 10**p.decimals()
        );
    }

    // withdraw random token transfer into this contract
    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) whenNotPaused {
        require(token != address(0), "token address is 0");
        require(token != config.underlying() && token != config.rhoToken(), "!safe");
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }

    function supplyRate() external view override returns (uint256) {
        return config.supplyRate();
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