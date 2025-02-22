// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAssetAllocation} from "contracts/common/Imports.sol";
import {SafeERC20, SafeMath} from "contracts/libraries/Imports.sol";
import {
    IOldStableSwap4 as IStableSwap,
    ILiquidityGauge
} from "contracts/protocols/curve/common/interfaces/Imports.sol";
import {CurveSusdv2Constants} from "./Constants.sol";
import {CurveGaugeZapBase} from "contracts/protocols/curve/common/Imports.sol";

contract CurveSusdv2Zap is CurveGaugeZapBase, CurveSusdv2Constants {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor()
        public
        CurveGaugeZapBase(
            STABLE_SWAP_ADDRESS,
            LP_TOKEN_ADDRESS,
            LIQUIDITY_GAUGE_ADDRESS,
            10000,
            100,
            4
        ) // solhint-disable-next-line no-empty-blocks
    {}

    function assetAllocations() public view override returns (string[] memory) {
        string[] memory allocationNames = new string[](1);
        allocationNames[0] = NAME;
        return allocationNames;
    }

    function erc20Allocations() public view override returns (IERC20[] memory) {
        IERC20[] memory allocations = _createErc20AllocationArray(2);
        allocations[4] = IERC20(SNX_ADDRESS);
        allocations[5] = IERC20(SUSD_ADDRESS);
        return allocations;
    }

    function _getVirtualPrice() internal view override returns (uint256) {
        return IStableSwap(SWAP_ADDRESS).get_virtual_price();
    }

    function _getCoinAtIndex(uint256 i)
        internal
        view
        override
        returns (address)
    {
        return IStableSwap(SWAP_ADDRESS).coins(int128(i));
    }

    function _addLiquidity(uint256[] calldata amounts, uint256 minAmount)
        internal
        override
    {
        IStableSwap(SWAP_ADDRESS).add_liquidity(
            [amounts[0], amounts[1], amounts[2], amounts[3]],
            minAmount
        );
    }

    function _removeLiquidity(
        uint256 lpBalance,
        uint8 index,
        uint256 minAmount
    ) internal override {
        require(index < 4, "INVALID_INDEX");

        uint256[] memory balances = new uint256[](4);
        for (uint256 i = 0; i < balances.length; i++) {
            if (i == index) continue;
            IERC20 inToken = IERC20(_getCoinAtIndex(i));
            balances[i] = inToken.balanceOf(address(this));
        }

        IStableSwap swap = IStableSwap(SWAP_ADDRESS);
        swap.remove_liquidity(
            lpBalance,
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );

        for (uint256 i = 0; i < balances.length; i++) {
            if (i == index) continue;
            IERC20 inToken = IERC20(_getCoinAtIndex(i));
            uint256 balanceDelta =
                inToken.balanceOf(address(this)).sub(balances[i]);
            inToken.safeApprove(address(swap), 0);
            inToken.safeApprove(address(swap), balanceDelta);
            swap.exchange(int128(i), index, balanceDelta, 0);
        }

        uint256 underlyerBalance =
            IERC20(_getCoinAtIndex(index)).balanceOf(address(this));
        require(underlyerBalance >= minAmount, "UNDER_MIN_AMOUNT");
    }

    /**
     * @dev claim protocol-specific rewards;
     *      CRV rewards are always claimed through the minter, in
     *      the `CurveGaugeZapBase` implementation.
     */
    function _claimRewards() internal override {
        ILiquidityGauge liquidityGauge = ILiquidityGauge(GAUGE_ADDRESS);
        liquidityGauge.claim_rewards();
    }
}