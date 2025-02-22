// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "hardhat/console.sol";

interface IFeePool {
    function feesAvailable(address account)
        external
        view
        returns (uint256, uint256);

    function isFeesClaimable(address account) external view returns (bool);

    function recentFeePeriods(uint256 index)
        external
        view
        returns (
            uint64 feePeriodId,
            uint64 startingDebtIndex,
            uint64 startTime,
            uint256 feesToDistribute,
            uint256 feesClaimed,
            uint256 rewardsToDistribute,
            uint256 rewardsClaimed
        );

    // Mutative Functions

    function claimOnBehalf(address claimingForAddress) external returns (bool);
}

interface IDelegateApprovals {
    function canClaimFor(address authoriser, address delegate)
        external
        view
        returns (bool);

    function approveClaimOnBehalf(address delegate) external;
}

contract SnxResolverMainnet {
    address public constant FEE_POOL =
        address(0xb440DD674e1243644791a4AdfE3A2AbB0A92d309);
    address public constant POKE_ME =
        address(0xB3f5503f93d5Ef84b06993a1975B9D21B962892F);
    address public constant APPROVALS =
        address(0x15fd6e554874B9e70F832Ed37f231Ac5E142362f);

    function test(address _addr) external view {
        IFeePool(FEE_POOL).feesAvailable(_addr);
    }

    function checker(address _account)
        external
        view
        returns (bool, bytes memory execPayload)
    {
        IFeePool feePool = IFeePool(FEE_POOL);
        IDelegateApprovals approvals = IDelegateApprovals(APPROVALS);

        (uint256 totalFees, uint256 totalRewards) = feePool.feesAvailable(
            _account
        );
        if (totalFees == 0 && totalRewards == 0) {
            execPayload = bytes("No fees to claim");
            return (false, execPayload);
        }

        if (!approvals.canClaimFor(_account, POKE_ME)) {
            execPayload = bytes("Not approved for claiming");
            return (false, execPayload);
        }

        if (!feePool.isFeesClaimable(_account)) {
            execPayload = bytes("Not claimable, cRatio too low");
            return (false, execPayload);
        }

        execPayload = abi.encodeWithSelector(
            feePool.claimOnBehalf.selector,
            _account
        );

        return (true, execPayload);
    }
}