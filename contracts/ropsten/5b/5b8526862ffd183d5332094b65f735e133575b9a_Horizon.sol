//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../interfaces/IHorizon.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IVaultConfig.sol";
import "../interfaces/IRhoToken.sol";
import "hardhat/console.sol";

contract Horizon is IHorizon, AccessControlEnumerableUpgradeable {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    // config
    IHorizonConfig public override config;

    // state
    uint256 public override flareId;
    mapping(bytes32 => IHorizonConfig.OptimalStrategy) public override optimalStrategy;

    function initialize(IHorizonConfig config_) public virtual initializer {
        config = config_;
    }

    function reportDistribution(uint256 flareId_) external override returns(IHorizonConfig.Distribution memory) {
        return _reportDistribution(flareId_);
    }
    function _reportDistribution(uint256 flareId_) internal returns(IHorizonConfig.Distribution memory dist)  {
        dist.underlyingIds = config.listIdentifier();
        dist.underlying = new IHorizonConfig.UnderlyingDistribution[](dist.underlyingIds.length);
        for (uint i = 0; i < dist.underlyingIds.length; i++) {
            IHorizonConfig.Asset memory asset = config.assets(dist.underlyingIds[i]);
            uint8 underlyingDecimal = asset.underlying.decimals();
            IVaultConfig.Strategy[] memory strategies = asset.vaultConfig.getStrategiesList();
            IHorizonConfig.Underlying memory underlyingUninvested = IHorizonConfig.Underlying(int248(int256(asset.vault.reserve())), underlyingDecimal);
            IHorizonConfig.Underlying memory underlyingInvested = IHorizonConfig.Underlying(0, underlyingDecimal);
            IHorizonConfig.Underlying memory redeployable = IHorizonConfig.Underlying(
                underlyingUninvested.amount - int248(int256(asset.vaultConfig.reserveLowerBound(asset.rhoToken.totalSupply() * 10 ** underlyingDecimal / 10 ** asset.rhoToken.decimals() ))), // reserve in excess
                underlyingDecimal
            );
            for (uint j = 0; j < strategies.length; j++ ) {
                redeployable.amount += int248(int256(strategies[j].target.underlyingWithdrawable()));
                underlyingInvested.amount += int248(int256(strategies[j].target.updateBalanceOfUnderlying()));
            }
            IHorizonConfig.ChainInfo[] memory cinfo = new IHorizonConfig.ChainInfo[](1);
            cinfo[0] = IHorizonConfig.ChainInfo(
                IHorizonConfig.InvestmentInfo(
                    underlyingUninvested,
                    underlyingInvested,
                    redeployable
                ),
                IHorizonConfig.RhoTokenInfo(
                    asset.rhoToken.adjustedRebasingSupply(),
                    asset.rhoToken.totalSupply()
                ),
                block.chainid
            );
            dist.underlying[i] = IHorizonConfig.UnderlyingDistribution(cinfo);
        }
        emit ReportDistribution(flareId_, dist);
    }

    function reportLocalOptimalAllocation(uint256[] calldata globalRedeployable) external view override returns(IHorizonConfig.Allocation memory alloc) {
        bytes32[] memory underlyingIds = config.listIdentifier();
        require(underlyingIds.length == globalRedeployable.length, "length not match");
        alloc.underlyingIds = underlyingIds;
        alloc.underlying = new IHorizonConfig.UnderlyingStrategy[](underlyingIds.length);
        for (uint i = 0; i < underlyingIds.length; i++) {
            IHorizonConfig.Asset memory asset = config.assets(underlyingIds[i]);
            require(address(asset.vault) != address(0), "vault not exist");
            IVaultConfig.Strategy[] memory strategies = asset.vaultConfig.getStrategiesList();
            uint240 optimalRate;
            uint8 optimalIndex;
            bytes12 checkByte;
            for (uint j = 0; j < strategies.length; j++ ) {
                uint256 rate = strategies[j].target.effectiveSupplyRate(globalRedeployable[i], true);
                if (rate > optimalRate) {
                    optimalRate = uint240(rate);
                    optimalIndex = uint8(j);
                    checkByte = bytes12(keccak256(abi.encodePacked(optimalIndex, address(strategies[j].target))));
                }
            }
            alloc.underlying[i].strategies = new IHorizonConfig.OptimalStrategy[](1);
            alloc.underlying[i].strategies[0] = IHorizonConfig.OptimalStrategy(
                block.chainid,
                optimalIndex,
                optimalRate,
                checkByte,
                address(asset.vault)
            );
        }
    }


    function receiveDividend(uint256 flareId_, int256 profit, bytes32 underlyingId) external override {
        _receiveDividend(flareId_, profit, underlyingId);
    }
    function _receiveDividend(uint256 flareId_, int256 profit, bytes32 underlyingId) internal {
        console.log("_receiveDividend");
        if (profit == 0) return;
        IVault v = config.assets(underlyingId).vault;
        require(address(v) != address(0), "vault not exist");
        console.log("_receiveDividend");
        v.receiveDividend(profit);
        console.log("_receiveDividend");
        emit DividendReceived(flareId_, profit, underlyingId);
    }

    function rebalance(uint256 flareId_, IHorizonConfig.Allocation calldata alloc, IHorizonConfig.Underlying calldata upfrontCost) external virtual override {
        require(flareId_ > flareId, "flareId already handled");
        _rebalance(alloc, upfrontCost);
        // mark as handled
        flareId = flareId_;
    }

    function _rebalance(IHorizonConfig.Allocation memory alloc, IHorizonConfig.Underlying calldata upfrontCost) internal {
        require(alloc.underlying.length == alloc.underlyingIds.length, "length not equal");
        for (uint i = 0; i < alloc.underlyingIds.length; i++) {
            IHorizonConfig.Asset memory asset = config.assets(alloc.underlyingIds[i]);
            if( address(asset.vault) != address(0)) {
                uint8 underlyingDecimals = asset.underlying.decimals();
                // has local vaults
                IHorizonConfig.OptimalStrategy memory optimal = alloc.underlying[i].strategies[0];
                (uint256 amount, uint256 cost) = asset.vault.rebalance(optimal, uint256(_translateUnderlying(upfrontCost, underlyingDecimals)));
                if (amount > 0) {
                    // record last switch cost
                    asset.lastSwitchOutAmount = IHorizonConfig.Underlying(
                        int248(int256(amount)),
                        underlyingDecimals
                    );
                    asset.lastSwitchOutCost = IHorizonConfig.Underlying(
                        int248(int256(cost)),
                        underlyingDecimals
                    );
                }
            }
            // store optimalAllocation for the sake of checking
            optimalStrategy[alloc.underlyingIds[i]] = alloc.underlying[i].strategies[0];
        }
    }

    function deployExcessReserve(IHorizonConfig.OptimalStrategy calldata s, bytes32 id, IHorizonConfig.Underlying calldata upfrontCost) external {
        IHorizonConfig.Asset memory asset = config.assets(id);
        int256 cost = _translateUnderlying(upfrontCost, asset.underlying.decimals());
        asset.vault.deployExcessReserve(s, cost > 0 ? uint256(cost) : 0);
    }

    function _translateUnderlying(IHorizonConfig.Underlying memory a, uint8 decimal) internal pure returns(int256) {
        return int256(a.amount) * int256(10**decimal) / int256(10**a.decimal);
    }
}