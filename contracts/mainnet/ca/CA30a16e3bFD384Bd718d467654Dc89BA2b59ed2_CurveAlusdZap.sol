// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAssetAllocation} from "contracts/common/Imports.sol";
import {CurveAlusdConstants} from "./Constants.sol";
import {
    MetaPoolDepositorZap
} from "contracts/protocols/curve/metapool/Imports.sol";

contract CurveAlusdZap is MetaPoolDepositorZap, CurveAlusdConstants {
    constructor()
        public
        MetaPoolDepositorZap(
            META_POOL,
            address(LP_TOKEN),
            address(LIQUIDITY_GAUGE),
            10000,
            100
        ) // solhint-disable-next-line no-empty-blocks
    {}

    function assetAllocations() public view override returns (string[] memory) {
        string[] memory allocationNames = new string[](1);
        allocationNames[0] = NAME;
        return allocationNames;
    }

    function erc20Allocations() public view override returns (IERC20[] memory) {
        IERC20[] memory allocations = _createErc20AllocationArray(2);
        allocations[4] = ALCX;
        allocations[5] = PRIMARY_UNDERLYER; // alUSD
        return allocations;
    }

    /**
     * @dev claim protocol-specific rewards;
     *      CRV rewards are always claimed through the minter, in
     *      the `CurveGaugeZapBase` implementation.
     */
    function _claimRewards() internal override {
        LIQUIDITY_GAUGE.claim_rewards();
    }
}