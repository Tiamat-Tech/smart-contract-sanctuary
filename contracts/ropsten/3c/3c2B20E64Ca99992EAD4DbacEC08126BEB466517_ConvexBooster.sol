// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./libs/SafeERC20.sol";
import "./convex/ConvexInterfaces.sol";
import "./common/IVirtualBalanceWrapper.sol";
import "./convex/ConvexStashTokens.sol";

contract ConvexBooster {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public convexRewardFactory;
    address public virtualBalanceWrapperFactory;
    address public convexBooster;
    address public rewardCrvToken;

    struct PoolInfo {
        uint256 originConvexPid;
        address curveSwapAddress; /* like 3pool https://github.com/curvefi/curve-js/blob/master/src/constants/abis/abis-ethereum.ts */
        address lpToken;
        address originCrvRewards;
        address originStash;
        address virtualBalance;
        address rewardPool;
        address stashToken;
        uint256 swapType;
        uint256 swapCoins;
    }

    PoolInfo[] public poolInfo;

    event Deposited(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        address _convexBooster,
        address _convexRewardFactory,
        address _virtualBalanceWrapperFactory,
        address _rewardCrvToken
    ) public {
        convexRewardFactory = _convexRewardFactory;
        convexBooster = _convexBooster;
        virtualBalanceWrapperFactory = _virtualBalanceWrapperFactory;
        rewardCrvToken = _rewardCrvToken;
    }

    function addConvexPool(
        uint256 _originConvexPid,
        address _curveSwapAddress,
        uint256 _swapType,
        uint256 _swapCoins
    ) public {
        (
            address lpToken,
            ,
            ,
            address originCrvRewards,
            address originStash,
            bool shutdown
        ) = IConvexBooster(convexBooster).poolInfo(_originConvexPid);

        require(shutdown == false, "!shutdown");

        address virtualBalance = IVirtualBalanceWrapperFactory(
            virtualBalanceWrapperFactory
        ).CreateVirtualBalanceWrapper(address(this));

        address rewardPool = IConvexRewardFactory(convexRewardFactory)
            .CreateRewards(rewardCrvToken, virtualBalance, address(this));

        address stashToken;

        uint256 extraRewardsLength = IConvexRewardPool(originCrvRewards)
            .extraRewardsLength();

        // if (originStash != address(0)) {
        if (extraRewardsLength > 0) {
            for (uint256 i = 0; i < extraRewardsLength; i++) {
                address extraRewardToken = IConvexRewardPool(originCrvRewards)
                    .extraRewards(i);

                address extraRewardPool = IConvexRewardFactory(
                    convexRewardFactory
                ).CreateRewards(
                        IConvexRewardPool(extraRewardToken).rewardToken(),
                        virtualBalance,
                        address(this)
                    );

                IConvexRewardPool(rewardPool).addExtraReward(extraRewardPool);
            }
            /* ConvexStashTokens convexStashTokens = new ConvexStashTokens(
                address(this),
                virtualBalance,
                poolInfo.length,
                stash
            );

            convexStashTokens.sync();

            stashToken = address(convexStashTokens); */
        }

        poolInfo.push(
            PoolInfo({
                originConvexPid: _originConvexPid,
                curveSwapAddress: _curveSwapAddress,
                lpToken: lpToken,
                originCrvRewards: originCrvRewards,
                originStash: originStash,
                virtualBalance: virtualBalance,
                rewardPool: rewardPool,
                stashToken: stashToken,
                swapType: _swapType,
                swapCoins: _swapCoins
            })
        );
    }

    /* function deposit(uint256 _pid, uint256 _amount) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        IERC20(pool.lpToken).safeTransferFrom(
            msg.sender,
            convexStaker,
            _amount
        );

        IConvexStaker(convexStaker).deposit(
            msg.sender,
            pool.targetPid,
            pool.lpToken,
            _amount,
            pool.rewardPool
        );

        emit Deposited(msg.sender, _pid, _amount);

        return true;
    } */

    function depositFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        IERC20(pool.lpToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // (
        //     address lpToken,
        //     address token,
        //     address gauge,
        //     address crvRewards,
        //     address stash,
        //     bool shutdown
        // ) = IConvexBooster(convexBooster).poolInfo(pool.convexPid);
        (, , , , , bool shutdown) = IConvexBooster(convexBooster).poolInfo(
            pool.originConvexPid
        );

        require(!shutdown, "!shutdown");

        uint256 balance = IERC20(pool.lpToken).balanceOf(address(this));

        if (balance > 0) {
            IERC20(pool.lpToken).safeApprove(convexBooster, 0);
            IERC20(pool.lpToken).safeApprove(convexBooster, balance);

            IConvexBooster(convexBooster).deposit(
                pool.originConvexPid,
                balance,
                true
            );
            // IConvexRewardPool(pool.rewardPool).stakeFor(_user, _amount);
            IVirtualBalanceWrapper(pool.virtualBalance).stakeFor(
                _user,
                _amount
            );
        }

        emit Deposited(_user, _pid, _amount);

        return true;
    }

    /* function withdraw(uint256 _pid, uint256 _amount) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        IConvexStaker(convexStaker).withdraw(
            msg.sender,
            _pid,
            pool.lpToken,
            _amount,
            pool.rewardPool
        );

        return true;
    } */
    function withdrawFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        // if (pool.stash != address(0)) {
        //     IConvexStash(pool.stash).stashRewards();
        // }

        // IConvexStaker(convexStaker).withdraw(
        //     _user,
        //     _pid,
        //     pool.lpToken,
        //     _amount,
        //     pool.rewardPool
        // );
        // 应该是去rewardPool中体现
        // IConvexBooster(convexBooster).withdraw(pool.convexPid, _amount);
        IConvexRewardPool(pool.originCrvRewards).withdrawAndUnwrap(
            _amount,
            true
        );
        IERC20(pool.lpToken).safeTransfer(_user, _amount);
        IVirtualBalanceWrapper(pool.virtualBalance).withdrawFor(_user, _amount);
        IConvexRewardPool(pool.rewardPool).getReward(_user, true);
        // IConvexRewardPool(pool.rewardPool).withdrawFor(_user, _amount);

        return true;
    }

    // function earmarkRewards(uint256 _pid) external returns (bool) {
    //     PoolInfo storage pool = poolInfo[_pid];

    //     if (pool.stashToken != address(0)) {
    //         ConvexStashTokens(pool.stashToken).stashRewards();
    //     }

    //     // if (pool.stash != address(0)) {
    //     //     //claim extra rewards
    //     //     IConvexStash(pool.stash).claimRewards();
    //     //     //process extra rewards
    //     //     IConvexStash(pool.stash).processStash();
    //     // }

    //     // IConvexStaker(convexStaker).earmarkRewards(
    //     //     pool.convexPid,
    //     //     pool.rewardPool
    //     // );

    //     // new
    //     // IConvexBooster(booster).earmarkRewards(_pid);

    //     // address crv = IConvexRewardPool(_rewardPool).rewardToken();
    //     // address cvx = IConvexRewardPool(_rewardPool).rewardConvexToken();
    //     // uint256 crvBal = IERC20(crv).balanceOf(address(this));
    //     // uint256 cvxBal = IERC20(cvx).balanceOf(address(this));

    //     // if (cvxBal > 0) {
    //     //     IERC20(cvx).safeTransfer(_rewardPool, cvxBal);
    //     // }

    //     // if (crvBal > 0) {
    //     //     IERC20(crv).safeTransfer(_rewardPool, crvBal);

    //     //     IConvexRewardPool(_rewardPool).queueNewRewards(crvBal);
    //     // }

    //     return true;
    // }

    //claim fees from curve distro contract, put in lockers' reward contract
    // function earmarkFees() external returns (bool) {
    //     // //claim fee rewards
    //     // IStaker(staker).claimFees(feeDistro, feeToken);
    //     // //send fee rewards to reward contract
    //     // uint256 _balance = IERC20(feeToken).balanceOf(address(this));
    //     // IERC20(feeToken).safeTransfer(lockFees, _balance);
    //     // IRewards(lockFees).queueNewRewards(_balance);
    //     return true;
    // }

    function liquidate(
        uint256 _pid,
        int128 _coinId,
        address _user,
        uint256 _amount
    ) external returns (address, uint256) {
        PoolInfo storage pool = poolInfo[_pid];

        // IConvexBooster(convexBooster).withdraw(pool.convexPid, _amount);
        IConvexRewardPool(pool.originCrvRewards).withdrawAndUnwrap(
            _amount,
            true
        );

        // IERC20(pool.lpToken).safeTransfer(_user, _amount);
        IVirtualBalanceWrapper(pool.virtualBalance).withdrawFor(_user, _amount);
        // IConvexRewardPool(pool.rewardPool).withdrawFor(_user, _amount);

        IERC20(pool.lpToken).safeApprove(pool.curveSwapAddress, 0);
        IERC20(pool.lpToken).safeApprove(pool.curveSwapAddress, _amount);

        address underlyToken = ICurveSwap(pool.curveSwapAddress).coins(
            uint256(_coinId)
        );

        if (pool.swapType == 0) {
            ICurveSwap(pool.curveSwapAddress).remove_liquidity_one_coin(
                _amount,
                _coinId,
                0
            );
        }

        if (pool.swapType == 1) {
            uint256[] memory min_amounts = new uint256[](pool.swapCoins);

            ICurveSwap(pool.curveSwapAddress).remove_liquidity(
                _amount,
                min_amounts
            );
        }

        // eth
        if (underlyToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            uint256 totalAmount = address(this).balance;

            msg.sender.transfer(totalAmount);

            return (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, totalAmount);
        } else {
            uint256 totalAmount = IERC20(underlyToken).balanceOf(address(this));

            IERC20(underlyToken).safeTransfer(msg.sender, totalAmount);

            return (underlyToken, totalAmount);
        }
    }

    function cliamRewardToken(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];

        address originCrvRewards = pool.originCrvRewards;
        address currentCrvRewards = pool.rewardPool;
        IConvexRewardPool(originCrvRewards).getReward(address(this), true);
        address rewardUnderlyToken = IConvexRewardPool(originCrvRewards)
            .rewardToken();
        uint256 crvBalance = IERC20(rewardUnderlyToken).balanceOf(
            address(this)
        );

        if (crvBalance > 0) {
            IERC20(rewardUnderlyToken).safeTransfer(
                currentCrvRewards,
                crvBalance
            );

            IConvexRewardPool(originCrvRewards).queueNewRewards(crvBalance);
        }

        uint256 extraRewardsLength = IConvexRewardPool(currentCrvRewards)
            .extraRewardsLength();

        if (extraRewardsLength > 0) {
            for (uint256 i = 0; i < extraRewardsLength; i++) {
                address currentExtraReward = IConvexRewardPool(
                    currentCrvRewards
                ).extraRewards(i);
                address originExtraRewardToken = IConvexRewardPool(
                    originCrvRewards
                ).extraRewards(i);
                address extraRewardUnderlyToken = IConvexRewardPool(
                    originExtraRewardToken
                ).rewardToken();

                IConvexRewardPool(originExtraRewardToken).getReward(
                    address(this)
                );

                uint256 extraBalance = IERC20(extraRewardUnderlyToken)
                    .balanceOf(address(this));

                if (extraBalance > 0) {
                    IERC20(extraRewardUnderlyToken).safeTransfer(
                        currentExtraReward,
                        extraBalance
                    );

                    IConvexRewardPool(currentExtraReward).queueNewRewards(
                        extraBalance
                    );
                }
            }
        }
    }

    function cliamAllRewardToken() public {
        for (uint256 i = 0; i < poolInfo.length; i++) {
            cliamRewardToken(i);
        }
    }

    // function cliamStashToken(
    //     address _token,
    //     address _rewardAddress,
    //     address _lfRewardAddress,
    //     uint256 _rewards
    // ) public {
    //     IConvexStashRewardPool(_rewardAddress).getReward(address(this));

    //     IERC20(_token).safeTransfer(_lfRewardAddress, _rewards);

    //     IConvexStashRewardPool(_rewardAddress).queueNewRewards(_rewards);
    // }

    receive() external payable {}

    /* view functions */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function totalSupplyOf(uint256 _pid) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];

        return IERC20(pool.lpToken).balanceOf(address(this));
    }
}