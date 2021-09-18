pragma solidity =0.7.6;
pragma abicoder v2;

import './interfaces/IFuzzyswapStaker.sol';
import './libraries/IncentiveId.sol';
import './libraries/RewardMath.sol';
import './libraries/NFTPositionInfo.sol';

import './FuzzyswapVirtualPool.sol';

import 'fuzzyswap/contracts/interfaces/IFuzzyswapPoolDeployer.sol';
import 'fuzzyswap/contracts/interfaces/IERC20Minimal.sol';
import 'fuzzyswap/contracts/interfaces/IFuzzyswapPool.sol';

import 'fuzzyswap-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import 'fuzzyswap-periphery/contracts/libraries/TransferHelper.sol';
import 'fuzzyswap-periphery/contracts/base/Multicall.sol';

/// @title Fuzzyswap canonical staking interface
contract FuzzyswapStaker is IFuzzyswapStaker, Multicall {
    /// @notice Represents a staking incentive
    struct Incentive {
        uint256 totalReward;
        address virtualPoolAddress;
        uint96 numberOfStakes;
        bool isPoolCreated;
    }

    /// @notice Represents the deposit of a liquidity NFT
    struct Deposit {
        address owner;
        uint48 numberOfStakes;
        int24 tickLower;
        int24 tickUpper;
    }

    /// @notice Represents a staked liquidity NFT
    struct Stake {
        uint96 liquidityNoOverflow;
        uint128 liquidityIfOverflow;
    }


    /// @inheritdoc IFuzzyswapStaker
    INonfungiblePositionManager public immutable override nonfungiblePositionManager;

    IFuzzyswapPoolDeployer public immutable override deployer;
  
    /// @inheritdoc IFuzzyswapStaker
    uint256 public immutable override maxIncentiveStartLeadTime;
    /// @inheritdoc IFuzzyswapStaker
    uint256 public immutable override maxIncentiveDuration;

    /// @dev bytes32 refers to the return value of IncentiveId.compute
    mapping(bytes32 => Incentive) public override incentives;

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public override deposits;

    /// @dev stakes[tokenId][incentiveHash] => Stake
    mapping(uint256 => mapping(bytes32 => Stake)) private _stakes;

    /// @inheritdoc IFuzzyswapStaker
    function stakes(uint256 tokenId, bytes32 incentiveId)
        public
        view
        override
        returns (uint128 liquidity)
    {
        Stake storage stake = _stakes[tokenId][incentiveId];
        liquidity = stake.liquidityNoOverflow;
        if (liquidity == type(uint96).max) {
            liquidity = stake.liquidityIfOverflow;
        }
    }

    /// @dev rewards[rewardToken][owner] => uint256
    /// @inheritdoc IFuzzyswapStaker
    mapping(IERC20Minimal => mapping(address => uint256)) public override rewards;
    
    /// @param _nonfungiblePositionManager the NFT position manager contract address
    /// @param _maxIncentiveStartLeadTime the max duration of an incentive in seconds
    /// @param _maxIncentiveDuration the max amount of seconds into the future the incentive startTime can be set
    constructor(
        IFuzzyswapPoolDeployer _deployer,
        INonfungiblePositionManager _nonfungiblePositionManager,
        uint256 _maxIncentiveStartLeadTime,
        uint256 _maxIncentiveDuration
    ) {
        deployer = _deployer;
        nonfungiblePositionManager = _nonfungiblePositionManager;
        maxIncentiveStartLeadTime = _maxIncentiveStartLeadTime;
        maxIncentiveDuration = _maxIncentiveDuration;
    }

    /// @inheritdoc IFuzzyswapStaker
    function createIncentive(IncentiveKey memory key, uint256 reward) external override returns(address virtualPool){
        require(reward > 0, 'FuzzyswapStaker::createIncentive: reward must be positive');
        require(
            block.timestamp <= key.startTime,
            'FuzzyswapStaker::createIncentive: start time must be now or in the future'
        );
        require(
            key.startTime - block.timestamp <= maxIncentiveStartLeadTime,
            'FuzzyswapStaker::createIncentive: start time too far into future'
        );
        require(key.startTime < key.endTime, 'FuzzyswapStaker::createIncentive: start time must be before end time');
        require(
            key.endTime - key.startTime <= maxIncentiveDuration,
            'FuzzyswapStaker::createIncentive: incentive duration is too long'
        );
 

        bytes32 incentiveId = IncentiveId.compute(key);

        incentives[incentiveId].totalReward += reward;

        virtualPool = address(new FuzzyswapVirtualPool(address(key.pool), address(this)));
        key.pool.setIncentive(virtualPool, uint32(key.endTime), uint32(key.startTime));
        
        incentives[incentiveId].isPoolCreated = true;
        incentives[incentiveId].virtualPoolAddress = address(virtualPool);

        TransferHelper.safeTransferFrom(address(key.rewardToken), msg.sender, address(this), reward);

        emit IncentiveCreated(key.rewardToken, key.pool, virtualPool, key.startTime, key.endTime, key.refundee, reward);
    }

    /// @inheritdoc IFuzzyswapStaker
//    function endIncentive(IncentiveKey memory key) external override returns (uint256 refund) {
//        require(block.timestamp >= key.endTime, 'FuzzyswapStaker::endIncentive: cannot end incentive before end time');
//
//        bytes32 incentiveId = IncentiveId.compute(key);
//        Incentive storage incentive = incentives[incentiveId];
//
//        refund = 0;
//
//        require(refund > 0, 'FuzzyswapStaker::endIncentive: no refund available');
//        require(
//            incentive.numberOfStakes == 0,
//            'FuzzyswapStaker::endIncentive: cannot end incentive while deposits are staked'
//        );
//
//        // issue the refund
//        incentive.totalReward = 0;
//        TransferHelper.safeTransfer(address(key.rewardToken), key.refundee, refund);
//
//        // note we never clear totalSecondsClaimedX128
//
//        emit IncentiveEnded(incentiveId, refund);
//    }

    /// @notice Upon receiving a Fuzzyswap ERC721, creates the token deposit setting owner to `from`. Also stakes token
    /// in one or more incentives if properly formatted `data` has a length > 0.
    /// @inheritdoc IERC721Receiver
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(
            msg.sender == address(nonfungiblePositionManager),
            'FuzzyswapStaker::onERC721Received: not a fuzzyswap nft'
        );

        (, , , , int24 tickLower, int24 tickUpper, , , , , ) = nonfungiblePositionManager.positions(tokenId);

        deposits[tokenId] = Deposit({owner: from, numberOfStakes: 0, tickLower: tickLower, tickUpper: tickUpper});
        emit DepositTransferred(tokenId, address(0), from);

        if (data.length > 0) {
            if (data.length == 160) {
                _stakeToken(abi.decode(data, (IncentiveKey)), tokenId);
            } else {
                IncentiveKey[] memory keys = abi.decode(data, (IncentiveKey[]));
                for (uint256 i = 0; i < keys.length; i++) {
                    _stakeToken(keys[i], tokenId);
                }
            }
        }
        return this.onERC721Received.selector;
    }

    /// @inheritdoc IFuzzyswapStaker
    function transferDeposit(uint256 tokenId, address to) external override {
        require(to != address(0), 'FuzzyswapStaker::transferDeposit: invalid transfer recipient');
        address owner = deposits[tokenId].owner;
        require(owner == msg.sender, 'FuzzyswapStaker::transferDeposit: can only be called by deposit owner');
        deposits[tokenId].owner = to;
        emit DepositTransferred(tokenId, owner, to);
    }

    /// @inheritdoc IFuzzyswapStaker
    function withdrawToken(
        uint256 tokenId,
        address to,
        bytes memory data
    ) external override {
        require(to != address(this), 'FuzzyswapStaker::withdrawToken: cannot withdraw to staker');
        Deposit memory deposit = deposits[tokenId];
        require(deposit.numberOfStakes == 0, 'FuzzyswapStaker::withdrawToken: cannot withdraw token while staked');
        require(deposit.owner == msg.sender, 'FuzzyswapStaker::withdrawToken: only owner can withdraw token');

        delete deposits[tokenId];
        emit DepositTransferred(tokenId, deposit.owner, address(0));

        nonfungiblePositionManager.safeTransferFrom(address(this), to, tokenId, data);
    }

    /// @inheritdoc IFuzzyswapStaker
    function stakeToken(IncentiveKey memory key, uint256 tokenId) external override {
        require(deposits[tokenId].owner == msg.sender, 'FuzzyswapStaker::stakeToken: only owner can stake token');
        require(deposits[tokenId].numberOfStakes == 0, 'FuzzyswapStaker::stakeToken: cannot stake token while staked'); 
        _stakeToken(key, tokenId);
    }

    /// @inheritdoc IFuzzyswapStaker
    function unstakeToken(IncentiveKey memory key, uint256 tokenId) external override {
        Deposit memory deposit = deposits[tokenId];
        bytes32 incentiveId = IncentiveId.compute(key);
        Incentive storage incentive = incentives[incentiveId];
        // anyone can call unstakeToken if the block time is after the end time of the incentive
        require(block.timestamp > key.endTime && IFuzzyswapVirtualPool(incentive.virtualPoolAddress).endTimestamp() != 0,
            "FuzzyswapStaker::unstakeToken: cannot unstake before end time");
        if (block.timestamp < key.endTime) {
            require(
                deposit.owner == msg.sender,
                'FuzzyswapStaker::unstakeToken: only owner can withdraw token before incentive end time'
            );
        }

        uint128 liquidity = stakes(tokenId, incentiveId);

        require(liquidity != 0, 'FuzzyswapStaker::unstakeToken: stake does not exist');

        deposits[tokenId].numberOfStakes--;
        incentive.numberOfStakes--;
        
        (uint160 secondsPerLiquidityInsideX128, uint initTimestamp, uint endTimestamp) = IFuzzyswapVirtualPool(incentive.virtualPoolAddress).getInnerSecondsPerLiquidity(deposit.tickLower, deposit.tickUpper);

        uint256 reward =
            RewardMath.computeRewardAmount(
                incentive.totalReward,
                initTimestamp,
                endTimestamp,
                liquidity,
                secondsPerLiquidityInsideX128,
                block.timestamp
            );

        rewards[key.rewardToken][deposit.owner] += reward;

        Stake storage stake = _stakes[tokenId][incentiveId];
        delete stake.liquidityNoOverflow;
        if (liquidity >= type(uint96).max) delete stake.liquidityIfOverflow;
        emit TokenUnstaked(tokenId, incentiveId, address(key.rewardToken), deposit.owner, reward);
    }

    /// @inheritdoc IFuzzyswapStaker
    function claimReward(
        IERC20Minimal rewardToken,
        address to,
        uint256 amountRequested
    ) external override returns (uint256 reward) {
        reward = rewards[rewardToken][msg.sender];
        console.log(reward, amountRequested);
        if (amountRequested != 0 && amountRequested < reward) {
            reward = amountRequested;
        }
        console.log(IERC20Minimal(address(rewardToken)).balanceOf(address(this)));
        rewards[rewardToken][msg.sender] -= reward;
        TransferHelper.safeTransfer(address(rewardToken), to, reward);

        emit RewardClaimed(to, reward, address(rewardToken), msg.sender);
    }

    /// @inheritdoc IFuzzyswapStaker
    function getRewardInfo(IncentiveKey memory key, uint256 tokenId)
        external
        view
        override
        returns (uint256 reward)
    {
        bytes32 incentiveId = IncentiveId.compute(key);

        uint128 liquidity = stakes(tokenId, incentiveId);
        require(liquidity > 0, 'FuzzyswapStaker::getRewardInfo: stake does not exist');

        Deposit memory deposit = deposits[tokenId];
        Incentive memory incentive = incentives[incentiveId];

        (uint160 secondsPerLiquidityInsideX128, uint initTimestamp, uint endTimestamp) = IFuzzyswapVirtualPool(incentive.virtualPoolAddress).getInnerSecondsPerLiquidity(deposit.tickLower, deposit.tickUpper);

        reward = RewardMath.computeRewardAmount(
            incentive.totalReward,
            initTimestamp,
            endTimestamp,
            liquidity,
            secondsPerLiquidityInsideX128,
            block.timestamp
        );
    }

    /// @dev Stakes a deposited token without doing an ownership check
    function _stakeToken(IncentiveKey memory key, uint256 tokenId) private {

        require(block.timestamp < key.startTime, 'FuzzyswapStaker::stakeToken: incentive has already started');

        bytes32 incentiveId = IncentiveId.compute(key);

        require(
            incentives[incentiveId].totalReward > 0,
            'FuzzyswapStaker::stakeToken: non-existent incentive'
        );
        require(
            _stakes[tokenId][incentiveId].liquidityNoOverflow == 0,
            'FuzzyswapStaker::stakeToken: token already staked'
        );

        (IFuzzyswapPool pool, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            NFTPositionInfo.getPositionInfo(deployer, nonfungiblePositionManager, tokenId);

        require(pool == key.pool, 'FuzzyswapStaker::stakeToken: token pool is not the incentive pool');
        require(liquidity > 0, 'FuzzyswapStaker::stakeToken: cannot stake token with 0 liquidity');


        deposits[tokenId].numberOfStakes++;
        incentives[incentiveId].numberOfStakes++;    
        (,int24 tick,,,,) = pool.globalState();
        IFuzzyswapVirtualPool virtualPool = IFuzzyswapVirtualPool(incentives[incentiveId].virtualPoolAddress);
        virtualPool.applyLiquidityDeltaToPosition(tickLower, tickUpper, int128(liquidity), tick);

        if (liquidity >= type(uint96).max) {
            _stakes[tokenId][incentiveId] = Stake({
                liquidityNoOverflow: type(uint96).max,
                liquidityIfOverflow: liquidity
            });
        } else {
            Stake storage stake = _stakes[tokenId][incentiveId];
            stake.liquidityNoOverflow = uint96(liquidity);
        }

        emit TokenStaked(tokenId, incentiveId, liquidity);
    }
}