pragma solidity >=0.7.6;
pragma abicoder v2;

import "../libraries/SafeMath.sol";
import "../libraries/Address.sol";
import "../libraries/trademint/PoolAddress.sol";
import "../interface/IERC20.sol";
import "../interface/ITokenIssue.sol";
import "../libraries/SafeERC20.sol";
import "../interface/trademint/ISummaSwapV3Manager.sol";
import "../interface/trademint/ITradeMint.sol";
import "../libraries/Context.sol";
import "../libraries/Owned.sol";
import "../libraries/FixedPoint128.sol";
import "../libraries/FullMath.sol";
import "../interface/ISummaPri.sol";

contract TradeMint is ITradeMint, Context, Owned {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    ITokenIssue public tokenIssue; // 发行合约 。根据发行合约的发行量分奖励，百分80给中心化挖矿，百分20给LP质押。这里从百分20中分

    ISummaSwapV3Manager public iSummaSwapV3Manager; // 管理合约地址。通过管理地址合约拿到用户LP情况

    uint256 public totalIssueRate = 0.1 * 10000; // TradeMint 占发行合约发行量的比例。

    uint256 public settlementBlock; //结算区块。每多少个区块结算一次

    mapping(address => bool) public isReward; //设置资金池是否可以获得奖励

    uint256 public totalRewardShare; // 每一个交易对的累加起来的总份额

    address public factory; //工厂地址合约

    uint256 public tradeShare; //交易占LP挖矿的比例

    bytes32 public constant PUBLIC_ROLE = keccak256("PUBLIC_ROLE"); //查询是否激活的Key

    uint24 public reduceFee; // 激活地址减少的手续费，设置 5 则减少1/5。激活的地址去交易比正常的地址少1/5的手续费

    uint24 private superFee; //激活地址如果存在上级。给上级的手续费。如设置 5.则给上级1/5. 激活的地址比正常的少1/5的手续费。而且剩下的4/5还要分出1/5给上级

    uint256 public easterEggPoint; //每次结算扣出来用作彩蛋资金的百分比

    uint256 public easterEggReward; //结算彩蛋的奖励百分。如果没有设置，默认百分百。如果某一次彩蛋资金过高。可以设置一个百分比。将资金留一部分下一次彩蛋

    bool public easterEggEnable;

    uint256 public luckNum;

    struct TickInfo {
        uint256 liquidityVolumeGrowthOutside; // Tick储存的 单位流动性交易量的增长。
        uint256 liquidityIncentiveGrowthOutside; // Tick储存 单位流动性 资金量的增长
        uint256 settlementBlock; // 该Tick 未结算的单位流动性交易量的增长，应该结算的区块
    }

    struct PoolInfo {
        uint256 lastSettlementBlock; // 上一次结算的区块
        mapping(int24 => TickInfo) ticks; //存储的Tick信息。Tick信息用来计算两个Tick之间组成的区间的奖励
        uint256 liquidityVolumeGrowth; // 全局单位流动性交易量增长
        uint256 liquidityIncentiveGrowth; //全局单位流动性 奖励增长
        uint256 rewardShare; // 资金池占的份额。与总份额对比计算每一个资金池能结算的奖励
        int24 currentTick; //资金池当前的Tick。根据当前Tick判断Tick存在的outside增长属于那一边
        uint256 unSettlementAmount; //资金池未结算的金额
        mapping(uint256 => uint256) blockSettlementVolume; // 结算时每一单位交易量 LP获取的奖励
        address poolAddress; //资金池地址
        mapping(uint256 => uint256) tradeSettlementAmountGrowth; // 结算时每一单位交易量 交易获取获取的奖励
        uint256 easterEgg; // 彩蛋 数值
        address[] rewardAddress; //中奖地址列表
    }

    struct UserInfo {
        uint256 tradeSettlementedAmount; // 用户交易结算的奖励
        uint256 tradeUnSettlementedAmount; // 用户交易未结算的交易量
        uint256 lastTradeBlock; //上一次交易的区块。根据上一次交易的区块计算用户应该结算在哪一个区块  根据用户应该结算的区块。找出已结算在资金池的每一个单位交易量应该获取的奖励。乘以用户的交易量。得到用户的应该分到的奖励
        uint256 lastRewardGrowthInside; // 用上一次提取奖励获取 或者追加流动性 记录当前的增长量。即之前的增长与该用户无关。在用户移除流动性或者追加流动性应提示用户先提取奖励。
    }

    address[] public poolAddress; //可以获取奖励的资金池地址列表

    uint256 public pledgeRate; //质押率

    uint256 public minPledge; //最小质押率

    address public summaAddress; //奖励SUMMMA的地址

    address public priAddress; //绑定关系的Pri合约地址

    mapping(address => mapping(address => UserInfo)) public userInfo; //根据用户地址跟资金池地址记录用户在每一个资金池的奖励信息

    mapping(address => PoolInfo) public poolInfoByPoolAddress; // 根据资金池地址找到资金池奖励信息

    uint256 public lastWithdrawBlock; // 上一次从发行合约提取SUM的区块。 用户提取SUM的时候会把当前区块到上一次提取的区块直接产生的发行量。提取对应的SUM到TradeMint

    event Cross(int24 _tick, int24 _nextTick);

    event Snapshot(
        address tradeAddress,
        int24 tick,
        uint256 liquidityVolumeGrowth,
        uint256 tradeVolume
    );

    event SnapshotLiquidity(
        address tradeAddress,
        address poolAddress,
        int24 _tickLower,
        int24 _tickUpper
    );

    //设置发行合约
    function setTokenIssue(ITokenIssue _tokenIssue) public onlyOwner {
        tokenIssue = _tokenIssue;
    }

    //设置NFT管理合约
    function setISummaSwapV3Manager(ISummaSwapV3Manager _ISummaSwapV3Manager)
        public
        onlyOwner
    {
        iSummaSwapV3Manager = _ISummaSwapV3Manager;
    }

    //设置 TradeMint 应该分到每一段结算区块产生的发行量的百分比。 以10000为单位。2000则表示，百分二十。从发行量中取出百分二十用来奖励交易跟LP挖矿
    function setTotalIssueRate(uint256 _totalIssueRate) public onlyOwner {
        totalIssueRate = _totalIssueRate;
    }

    //设置结算区块
    function setSettlementBlock(uint256 _settlementBlock) public onlyOwner {
        settlementBlock = _settlementBlock;
    }

    //设置工厂地址合约
    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }

    //设置交易奖励占比
    function setTradeShare(uint256 _tradeShare) public onlyOwner {
        tradeShare = _tradeShare;
    }

    //设置最小质押率
    function setPledgeRate(uint256 _pledgeRate) public onlyOwner {
        pledgeRate = _pledgeRate;
    }

    // 设置最小质押值
    function setMinPledge(uint256 _minPledge) public onlyOwner {
        minPledge = _minPledge;
    }

    //设置SUMMA 奖励SUMMA的地址
    function setSummaAddress(address _summaAddress) public onlyOwner {
        summaAddress = _summaAddress;
    }

    //设置pri推荐关系绑定合约
    function setPriAddress(address _priAddress) public onlyOwner {
        priAddress = _priAddress;
    }

    //设置上级减少的手续费比例。5表示减少1/5
    function setReduceFee(uint24 _reduceFee) public onlyOwner {
        reduceFee = _reduceFee;
    }

    //设置给上级的手续费比例。5表示给上级1/5
    function setSuperFee(uint24 _superFee) public onlyOwner {
        superFee = _superFee;
    }

    //设置某一个资金池是否可以获取奖励。true 表示该资金池可以获取奖励。如果是true _rewardShare 必须大于0.如果是false。则必须上一次设置了奖励的。因为添加了新的交易对。奖励分配比例发生了变化。所有要把之前的交易对都结算。
    function enableReward(
        address _poolAddress,
        bool _isReward,
        uint256 _rewardShare
    ) public onlyOwner {
        require(settlementBlock > 0, "error settlementBlock");
        massUpdatePools();
        if (_isReward) {
            require(_rewardShare > 0, "error rewardShare");
            PoolInfo storage _poolInfo = poolInfoByPoolAddress[_poolAddress];
            _poolInfo.lastSettlementBlock = block
                .number
                .div(settlementBlock)
                .mul(settlementBlock);
            if (poolAddress.length == 0) {
                lastWithdrawBlock = _poolInfo.lastSettlementBlock;
            }
            _poolInfo.poolAddress = _poolAddress;
            _poolInfo.rewardShare = _rewardShare;
            totalRewardShare += _rewardShare;
            poolAddress.push(_poolAddress);
        } else {
            require(isReward[_poolAddress], "pool is not reward");
            PoolInfo storage _poolInfo = poolInfoByPoolAddress[_poolAddress];
            totalRewardShare -= _poolInfo.rewardShare;
            _poolInfo.rewardShare = 0;
        }
        isReward[_poolAddress] = _isReward;
    }

    function rand(uint256 _length) public view returns (uint256) {
        uint256 random = uint256(
            keccak256(abi.encodePacked(block.difficulty, block.timestamp))
        );
        return random % _length;
    }

    //设置某一个资金池是否可以获取奖励。true 表示该资金池可以获取奖励。如果是true _rewardShare 必须大于0.如果是false。则必须上一次设置了奖励的。因为添加了新的交易对。奖励分配比例发生了变化。所有要把之前的交易对都结算。
    function enableReward(
        address token0,
        address token1,
        uint24 fee,
        bool _isReward,
        uint256 _rewardShare
    ) public onlyOwner {
        require(settlementBlock > 0, "error settlementBlock");
        address _poolAddress = PoolAddress.computeAddress(
            factory,
            token0,
            token1,
            fee
        );
        massUpdatePools();
        if (_isReward) {
            require(_rewardShare > 0, "error rewardShare");
            PoolInfo storage _poolInfo = poolInfoByPoolAddress[_poolAddress];
            _poolInfo.lastSettlementBlock = block
                .number
                .div(settlementBlock)
                .mul(settlementBlock);
            if (poolAddress.length == 0) {
                lastWithdrawBlock = _poolInfo.lastSettlementBlock;
            }
            _poolInfo.poolAddress = _poolAddress;
            _poolInfo.rewardShare = _rewardShare;
            totalRewardShare += _rewardShare;
            poolAddress.push(_poolAddress);
        } else {
            require(isReward[_poolAddress], "pool is not reward");
            PoolInfo storage _poolInfo = poolInfoByPoolAddress[_poolAddress];
            totalRewardShare -= _poolInfo.rewardShare;
            _poolInfo.rewardShare = 0;
        }
        isReward[_poolAddress] = _isReward;
    }

    function setEasterEggPoint(uint256 _easterEggPoint) public onlyOwner {
        easterEggPoint = _easterEggPoint;
    }

    function setEasterEggReward(uint256 _easterEggReward) public onlyOwner {
        easterEggReward = _easterEggReward;
    }

    function setEasterEggEnable(bool _easterEggEnable) public onlyOwner {
        require(luckNum > 0, "please set luckNum");
        easterEggEnable = _easterEggEnable;
    }

    function setLuckNum(uint256 _luckNum) public onlyOwner {
        luckNum = _luckNum;
    }

    function withdrawSumma(uint256 amount) public onlyOwner {
        IERC20(summaAddress).safeTransfer(msg.sender, amount);
    }

    function massUpdatePools() public {
        uint256 length = poolAddress.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        address _poolAddress = poolAddress[_pid];
        PoolInfo storage poolInfo = poolInfoByPoolAddress[_poolAddress];
        if (
            poolInfo.lastSettlementBlock.add(settlementBlock) <= block.number &&
            poolInfo.unSettlementAmount > 0
        ) {
            uint256 form = poolInfo.lastSettlementBlock;
            uint256 to = (form.add(settlementBlock));
            uint256 summaReward = getMultiplier(form, to)
                .mul(poolInfo.rewardShare)
                .div(totalRewardShare);
            poolInfo.easterEgg += summaReward.mul(easterEggPoint).div(100); //彩蛋抽成
            settlementTrade(
                poolInfo.poolAddress,
                (summaReward.sub(summaReward.mul(easterEggPoint).div(100))).div(
                    tradeShare
                )
            ); //结算交易
            settlementPoolNewLiquidityIncentiveGrowth(poolInfo.poolAddress);
        } else if (
            block.number.div(settlementBlock).mul(settlementBlock) >
            poolInfo.lastSettlementBlock
        ) {
            poolInfo.easterEgg += getMultiplier(
                poolInfo.lastSettlementBlock,
                block.number.div(settlementBlock).mul(settlementBlock)
            ).mul(poolInfo.rewardShare).div(totalRewardShare);
        }
    }

    function pendingSumma(address userAddress) public view returns (uint256) {
        uint256 amount = 0;
        uint256 length = poolAddress.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            address _poolAddress = poolAddress[pid];
            PoolInfo storage poolInfo = poolInfoByPoolAddress[_poolAddress];
            UserInfo storage userInfo = userInfo[userAddress][poolAddress[pid]];
            if (userInfo.lastTradeBlock != 0) {
                if (userInfo.lastTradeBlock < poolInfo.lastSettlementBlock) {
                    amount += FullMath.mulDiv(
                        userInfo.tradeUnSettlementedAmount,
                        poolInfo.tradeSettlementAmountGrowth[
                            (
                                userInfo
                                    .lastTradeBlock
                                    .div(settlementBlock)
                                    .add(1)
                            ).mul(settlementBlock)
                        ],
                        FixedPoint128.Q128
                    );
                } else if (
                    (userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(
                        settlementBlock
                    ) <=
                    block.number &&
                    poolInfo.unSettlementAmount > 0
                ) {
                    uint256 form = (
                        userInfo.lastTradeBlock.div(settlementBlock)
                    ).mul(settlementBlock);
                    uint256 to = (
                        userInfo.lastTradeBlock.div(settlementBlock).add(1)
                    ).mul(settlementBlock);
                    uint256 summaReward = getMultiplier(form, to)
                        .mul(poolInfo.rewardShare)
                        .div(totalRewardShare);
                    uint256 tradeReward = (
                        summaReward.sub(
                            summaReward.mul(easterEggPoint).div(100)
                        )
                    ).div(tradeShare);
                    uint256 quotient = FullMath.mulDiv(
                        tradeReward,
                        FixedPoint128.Q128,
                        poolInfo.unSettlementAmount
                    );
                    amount += FullMath.mulDiv(
                        quotient,
                        userInfo.tradeUnSettlementedAmount,
                        FixedPoint128.Q128
                    );
                }
                amount +=userInfo.tradeSettlementedAmount;
            }
        }
        uint256 balance = iSummaSwapV3Manager.balanceOf(userAddress);
        for (uint256 pid = 0; pid < balance; ++pid) {
            (
                ,
                ,
                address token0,
                address token1,
                uint24 fee,
                int24 tickLower,
                int24 tickUpper,
                uint128 liquidity,
                ,
                ,
                ,

            ) = iSummaSwapV3Manager.positions(
                    iSummaSwapV3Manager.tokenOfOwnerByIndex(userAddress, pid)
                );
            address poolAddress = PoolAddress.computeAddress(
                factory,
                token0,
                token1,
                fee
            );
            if (isReward[poolAddress]) {
                uint256 userLastReward = userInfo[userAddress][poolAddress]
                    .lastRewardGrowthInside;
                uint256 liquidityIncentiveGrowthInPosition = getLiquidityIncentiveGrowthInPosition(
                        tickLower,
                        tickUpper,
                        poolAddress
                    ).sub(userLastReward);
                amount += FullMath.mulDiv(
                    liquidityIncentiveGrowthInPosition,
                    liquidity,
                    FixedPoint128.Q128
                );
            }
        }
        return amount;
    }

    function getEasterEgg(address poolAddress) public view returns (uint256) {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        uint256 easterEgg = poolInfo.easterEgg;
        if (
            block.number.div(settlementBlock).mul(settlementBlock) >
            poolInfo.lastSettlementBlock
        ) {
            easterEgg += getMultiplier(
                poolInfo.lastSettlementBlock,
                block.number.div(settlementBlock).mul(settlementBlock)
            ).mul(poolInfo.rewardShare).div(totalRewardShare);
        }
        return easterEgg;
    }

    function getPoolReward(address poolAddress)
        internal
        view
        returns (uint256)
    {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];

        uint256 form = poolInfo.lastSettlementBlock;
        uint256 to = poolInfo.lastSettlementBlock.add(settlementBlock);
        uint256 multiplier = getMultiplier(form, to);
        uint256 reward = multiplier
            .mul(poolInfo.rewardShare)
            .mul(uint256(100).sub(easterEggPoint))
            .div(100)
            .div(totalRewardShare)
            .div(tradeShare)
            .mul(tradeShare.sub(1));
        return reward;
    }

    function getLiquidityIncentiveGrowthInPosition(
        int24 _tickLower,
        int24 _tickUpper,
        address poolAddress
    ) internal view returns (uint256) {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        uint256 newLiquidityIncentiveGrowth = poolInfo.liquidityIncentiveGrowth;
        if (
            poolInfo.lastSettlementBlock.add(settlementBlock) <= block.number &&
            poolInfo.unSettlementAmount > 0
        ) {
            newLiquidityIncentiveGrowth = getPoolNewLiquidityIncentiveGrowth(
                poolAddress
            );
        }
        TickInfo storage tickLower = poolInfo.ticks[_tickLower];
        uint256 newLowerLiquidityIncentiveGrowthOutside = tickLower
            .liquidityIncentiveGrowthOutside;
        if (tickLower.liquidityVolumeGrowthOutside != 0) {
            newLowerLiquidityIncentiveGrowthOutside =
                newLowerLiquidityIncentiveGrowthOutside +
                FullMath.mulDiv(
                    tickLower.liquidityVolumeGrowthOutside,
                    poolInfo.blockSettlementVolume[tickLower.settlementBlock],
                    FixedPoint128.Q128
                );
        }
        TickInfo storage tickUpper = poolInfo.ticks[_tickUpper];
        uint256 newUpLiquidityIncentiveGrowthOutside = tickUpper
            .liquidityIncentiveGrowthOutside;
        if (tickUpper.liquidityVolumeGrowthOutside != 0) {
            newUpLiquidityIncentiveGrowthOutside =
                newUpLiquidityIncentiveGrowthOutside +
                FullMath.mulDiv(
                    tickUpper.liquidityVolumeGrowthOutside,
                    poolInfo.blockSettlementVolume[tickUpper.settlementBlock],
                    FixedPoint128.Q128
                );
        }
        // calculate fee growth below
        uint256 feeGrowthBelow;
        if (poolInfo.currentTick >= _tickLower) {
            feeGrowthBelow = newLowerLiquidityIncentiveGrowthOutside;
        } else {
            feeGrowthBelow =
                newLiquidityIncentiveGrowth -
                newLowerLiquidityIncentiveGrowthOutside;
        }
        uint256 feeGrowthAbove;
        if (poolInfo.currentTick < _tickUpper) {
            feeGrowthAbove = newUpLiquidityIncentiveGrowthOutside;
        } else {
            feeGrowthAbove =
                newLiquidityIncentiveGrowth -
                newUpLiquidityIncentiveGrowthOutside;
        }
        uint256 feeGrowthInside = newLiquidityIncentiveGrowth -
            feeGrowthBelow -
            feeGrowthAbove;
        return feeGrowthInside;
    }

    function settlementLiquidityIncentiveGrowthInPosition(
        int24 _tickLower,
        int24 _tickUpper,
        address poolAddress
    ) internal returns (uint256) {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];

        if (
            poolInfo.lastSettlementBlock.add(settlementBlock) <= block.number &&
            poolInfo.unSettlementAmount > 0
        ) {
            settlementPoolNewLiquidityIncentiveGrowth(poolAddress);
        } else if (
            block.number.div(settlementBlock).mul(settlementBlock) >
            poolInfo.lastSettlementBlock
        ) {
            poolInfo.easterEgg += getMultiplier(
                poolInfo.lastSettlementBlock,
                block.number.div(settlementBlock).mul(settlementBlock)
            ).mul(poolInfo.rewardShare).div(totalRewardShare);
        }
        uint256 newLiquidityIncentiveGrowth = poolInfo.liquidityIncentiveGrowth;
        if (newLiquidityIncentiveGrowth == 0) {
            return 0;
        }
        TickInfo storage tickLower = poolInfo.ticks[_tickLower];
        if (
            poolInfo.blockSettlementVolume[tickLower.settlementBlock] > 0 &&
            tickLower.liquidityVolumeGrowthOutside > 0
        ) {
            tickLower.liquidityIncentiveGrowthOutside =
                tickLower.liquidityIncentiveGrowthOutside +
                FullMath.mulDiv(
                    tickLower.liquidityVolumeGrowthOutside,
                    poolInfo.blockSettlementVolume[tickLower.settlementBlock],
                    FixedPoint128.Q128
                );
        }
        uint256 newLowerLiquidityIncentiveGrowthOutside = tickLower
            .liquidityIncentiveGrowthOutside;
        TickInfo storage tickUpper = poolInfo.ticks[_tickUpper];
        if (
            poolInfo.blockSettlementVolume[tickUpper.settlementBlock] > 0 &&
            tickUpper.liquidityVolumeGrowthOutside > 0
        ) {
            tickUpper.liquidityIncentiveGrowthOutside =
                tickUpper.liquidityIncentiveGrowthOutside +
                FullMath.mulDiv(
                    tickUpper.liquidityVolumeGrowthOutside,
                    poolInfo.blockSettlementVolume[tickLower.settlementBlock],
                    FixedPoint128.Q128
                );
        }
        uint256 newUpLiquidityIncentiveGrowthOutside = tickUpper
            .liquidityIncentiveGrowthOutside;
        // calculate fee growth below
        uint256 feeGrowthBelow;
        if (poolInfo.currentTick >= _tickLower) {
            feeGrowthBelow = newLowerLiquidityIncentiveGrowthOutside;
        } else {
            feeGrowthBelow =
                newLiquidityIncentiveGrowth -
                newLowerLiquidityIncentiveGrowthOutside;
        }
        uint256 feeGrowthAbove;
        if (poolInfo.currentTick < _tickUpper) {
            feeGrowthAbove = newUpLiquidityIncentiveGrowthOutside;
        } else {
            feeGrowthAbove =
                newLiquidityIncentiveGrowth -
                newUpLiquidityIncentiveGrowthOutside;
        }
        uint256 feeGrowthInside = newLiquidityIncentiveGrowth -
            feeGrowthBelow -
            feeGrowthAbove;
        return feeGrowthInside;
    }

    function settlementPoolNewLiquidityIncentiveGrowth(address poolAddress)
        internal
        returns (uint256)
    {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        uint256 reward = getPoolReward(poolAddress);
        poolInfo.liquidityIncentiveGrowth +=
            poolInfo.liquidityIncentiveGrowth +
            reward.mul(poolInfo.liquidityVolumeGrowth).div(
                poolInfo.unSettlementAmount
            );
        poolInfo.liquidityVolumeGrowth = 0;
        poolInfo.blockSettlementVolume[
            poolInfo.lastSettlementBlock.add(settlementBlock)
        ] = FullMath.mulDiv(
            reward,
            FixedPoint128.Q128,
            poolInfo.unSettlementAmount
        );
        poolInfo.unSettlementAmount = 0;
        poolInfo.lastSettlementBlock = poolInfo.lastSettlementBlock.add(
            settlementBlock
        );
        if (
            block.number.div(settlementBlock).mul(settlementBlock) >
            poolInfo.lastSettlementBlock
        ) {
            poolInfo.easterEgg += getMultiplier(
                poolInfo.lastSettlementBlock,
                block.number.div(settlementBlock).mul(settlementBlock)
            ).mul(poolInfo.rewardShare).div(totalRewardShare);
        }
        return poolInfo.liquidityIncentiveGrowth;
    }

    function getPoolNewLiquidityIncentiveGrowth(address poolAddress)
        internal
        view
        returns (uint256)
    {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        uint256 reward = getPoolReward(poolAddress);
        uint256 newLiquidityIncentiveGrowth = poolInfo
            .liquidityIncentiveGrowth
            .add(
                reward.mul(poolInfo.liquidityVolumeGrowth).div(
                    poolInfo.unSettlementAmount
                )
            );
        return newLiquidityIncentiveGrowth;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        uint256 issueTime = tokenIssue.startIssueTime();
        if (_to < issueTime) {
            return 0;
        }
        if (_from < issueTime) {
            return getIssue(issueTime, _to).mul(totalIssueRate).div(10000);
        }
        return
            getIssue(issueTime, _to)
                .sub(getIssue(issueTime, _from))
                .mul(totalIssueRate)
                .div(10000);
    }

    function withdraw() public {
        require(lastWithdrawBlock != 0);
        uint256 summaReward = getMultiplier(lastWithdrawBlock, block.number);
        tokenIssue.transByContract(address(this), summaReward);
        lastWithdrawBlock = block.number;
        uint256 amount = withdrawSettlement();
        uint256 pledge = amount.mul(pledgeRate).div(100);
        if (pledge < 100 * 10**18) {
            pledge = 100 * 10**18;
        }
        require(
            IERC20(summaAddress).balanceOf(msg.sender) > pledge,
            "Insufficient pledge"
        );
        IERC20(summaAddress).safeTransfer(address(msg.sender), amount);
    }

    function settlementTrade(
        address tradeAddress,
        address poolAddress,
        uint256 summaReward
    ) internal {
        UserInfo storage userInfo = userInfo[tradeAddress][poolAddress];
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        poolInfo.tradeSettlementAmountGrowth[
            poolInfo.lastSettlementBlock.add(settlementBlock)
        ] += FullMath.mulDiv(
            summaReward,
            FixedPoint128.Q128,
            poolInfo.unSettlementAmount
        );
        userInfo.tradeSettlementedAmount += FullMath.mulDiv(
            userInfo.tradeUnSettlementedAmount,
            poolInfo.tradeSettlementAmountGrowth[
                (userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(
                    settlementBlock
                )
            ],
            FixedPoint128.Q128
        );
        userInfo.tradeUnSettlementedAmount = 0;
    }

    //结算资金池的奖励
    function settlementTrade(address poolAddress, uint256 summaReward)
        internal
    {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        poolInfo.tradeSettlementAmountGrowth[
            poolInfo.lastSettlementBlock.add(settlementBlock)
        ] += FullMath.mulDiv(
            summaReward,
            FixedPoint128.Q128,
            poolInfo.unSettlementAmount
        );
    }

    function withdrawSettlement() internal returns (uint256) {
        uint256 amount = 0;
        uint256 length = poolAddress.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            address _poolAddress = poolAddress[pid];
            PoolInfo storage poolInfo = poolInfoByPoolAddress[_poolAddress];
            UserInfo storage userInfo = userInfo[msg.sender][poolAddress[pid]];
            if (userInfo.lastTradeBlock != 0) {
                if (userInfo.lastTradeBlock < poolInfo.lastSettlementBlock) {
                    userInfo.tradeSettlementedAmount += FullMath.mulDiv(
                        userInfo.tradeUnSettlementedAmount,
                        poolInfo.tradeSettlementAmountGrowth[
                            (
                                userInfo
                                    .lastTradeBlock
                                    .div(settlementBlock)
                                    .add(1)
                            ).mul(settlementBlock)
                        ],
                        FixedPoint128.Q128
                    );
                    userInfo.tradeUnSettlementedAmount = 0;
                } else if (
                    (userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(
                        settlementBlock
                    ) <=
                    block.number &&
                    poolInfo.unSettlementAmount > 0
                ) {
                    uint256 form = (
                        userInfo.lastTradeBlock.div(settlementBlock)
                    ).mul(settlementBlock);
                    uint256 to = (form.add(settlementBlock));
                    uint256 summaReward = getMultiplier(form, to)
                        .mul(poolInfo.rewardShare)
                        .div(totalRewardShare);
                    poolInfo.easterEgg += summaReward.mul(easterEggPoint).div(
                        100
                    ); //彩蛋抽成
                    poolInfo.tradeSettlementAmountGrowth[to] += FullMath.mulDiv(
                        (
                            summaReward.sub(
                                summaReward.mul(easterEggPoint).div(100)
                            )
                        ).div(tradeShare),
                        FixedPoint128.Q128,
                        poolInfo.unSettlementAmount
                    );
                    userInfo.tradeSettlementedAmount += FullMath.mulDiv(
                        userInfo.tradeUnSettlementedAmount,
                        poolInfo.tradeSettlementAmountGrowth[to],
                        FixedPoint128.Q128
                    );
                    userInfo.tradeUnSettlementedAmount = 0;
                }
                amount += userInfo.tradeSettlementedAmount;
                userInfo.tradeSettlementedAmount = 0;
            }
        }
        uint256 balance = iSummaSwapV3Manager.balanceOf(msg.sender);
        for (uint256 pid = 0; pid < balance; ++pid) {
            (
                ,
                ,
                address token0,
                address token1,
                uint24 fee,
                int24 tickLower,
                int24 tickUpper,
                uint128 liquidity,
                ,
                ,
                ,

            ) = iSummaSwapV3Manager.positions(
                    iSummaSwapV3Manager.tokenOfOwnerByIndex(msg.sender, pid)
                );
            address poolAddress = PoolAddress.computeAddress(
                factory,
                token0,
                token1,
                fee
            );
            if (isReward[poolAddress]) {
                uint256 newLiquidityIncentiveGrowthInPosition = settlementLiquidityIncentiveGrowthInPosition(
                        tickLower,
                        tickUpper,
                        poolAddress
                    );

                uint256 liquidityIncentiveGrowthInPosition = newLiquidityIncentiveGrowthInPosition
                        .sub(
                            userInfo[msg.sender][poolAddress]
                                .lastRewardGrowthInside
                        );
                userInfo[msg.sender][poolAddress]
                    .lastRewardGrowthInside = newLiquidityIncentiveGrowthInPosition;
                amount += FullMath.mulDiv(
                    liquidityIncentiveGrowthInPosition,
                    liquidity,
                    FixedPoint128.Q128
                );
            }
        }
        return amount;
    }

    function getIssue(uint256 _from, uint256 _to)
        private
        view
        returns (uint256)
    {
        if (_to <= _from || _from <= 0) {
            return 0;
        }
        uint256 timeInterval = _to - _from;
        uint256 monthIndex = timeInterval.div(tokenIssue.MONTH_SECONDS());
        if (monthIndex < 1) {
            return
                timeInterval.mul(
                    tokenIssue.issueInfo(monthIndex).div(
                        tokenIssue.MONTH_SECONDS()
                    )
                );
        } else if (monthIndex < tokenIssue.issueInfoLength()) {
            uint256 tempTotal = 0;
            for (uint256 j = 0; j < monthIndex; j++) {
                tempTotal = tempTotal.add(tokenIssue.issueInfo(j));
            }
            uint256 calcAmount = timeInterval
                .sub(monthIndex.mul(tokenIssue.MONTH_SECONDS()))
                .mul(
                    tokenIssue.issueInfo(monthIndex).div(
                        tokenIssue.MONTH_SECONDS()
                    )
                )
                .add(tempTotal);
            if (
                calcAmount >
                tokenIssue.TOTAL_AMOUNT().sub(tokenIssue.INIT_MINE_SUPPLY())
            ) {
                return
                    tokenIssue.TOTAL_AMOUNT().sub(
                        tokenIssue.INIT_MINE_SUPPLY()
                    );
            }
            return calcAmount;
        } else {
            return 0;
        }
    }

    function cross(int24 _tick, int24 _nextTick) external override {
        require(Address.isContract(_msgSender()));
        PoolInfo storage poolInfo = poolInfoByPoolAddress[_msgSender()];
        if (isReward[_msgSender()]) {
            poolInfo.currentTick = _nextTick;
            TickInfo storage tick = poolInfo.ticks[_tick];
            if (tick.liquidityVolumeGrowthOutside > 0) {
                tick.liquidityIncentiveGrowthOutside =
                    tick.liquidityIncentiveGrowthOutside +
                    FullMath.mulDiv(
                        poolInfo.blockSettlementVolume[tick.settlementBlock],
                        tick.liquidityVolumeGrowthOutside,
                        FixedPoint128.Q128
                    );
            }
            tick.liquidityIncentiveGrowthOutside =
                poolInfo.liquidityIncentiveGrowth -
                tick.liquidityIncentiveGrowthOutside;
            tick.liquidityVolumeGrowthOutside =
                poolInfo.liquidityVolumeGrowth -
                tick.liquidityVolumeGrowthOutside;
            tick.settlementBlock = (block.number.div(settlementBlock).add(1))
                .mul(settlementBlock);
            emit Cross(_tick, _nextTick);
        }
    }

    function snapshot(
        address tradeAddress,
        int24 tick,
        uint256 liquidityVolumeGrowth,
        uint256 tradeVolume
    ) external override {
        require(Address.isContract(_msgSender()));
        PoolInfo storage poolInfo = poolInfoByPoolAddress[_msgSender()];
        if (isReward[_msgSender()]) {
            if (
                poolInfo.lastSettlementBlock.add(settlementBlock) <=
                block.number &&
                poolInfo.unSettlementAmount > 0
            ) {
                uint256 form = poolInfo.lastSettlementBlock;
                uint256 to = (form.add(settlementBlock));
                uint256 summaReward = getMultiplier(form, to)
                    .mul(poolInfo.rewardShare)
                    .div(totalRewardShare);
                poolInfo.easterEgg += summaReward.mul(easterEggPoint).div(100); //彩蛋抽成
                settlementTrade(
                    tradeAddress,
                    _msgSender(),
                    (summaReward.sub(summaReward.mul(easterEggPoint).div(100)))
                        .div(tradeShare)
                );
                settlementPoolNewLiquidityIncentiveGrowth(_msgSender());
                if (easterEggEnable && poolInfo.easterEgg > 0) {
                    if (rand(luckNum) == 0) {
                        uint256 eggAmount = poolInfo
                            .easterEgg
                            .mul(easterEggReward)
                            .div(100);
                        poolInfo.rewardAddress.push(tradeAddress);
                        IERC20(summaAddress).safeTransfer(
                            tradeAddress,
                            eggAmount
                        );
                    }
                }
            }
            UserInfo storage userInfo = userInfo[tradeAddress][_msgSender()];
            userInfo.tradeUnSettlementedAmount += tradeVolume;
            userInfo.lastTradeBlock = block.number;
            poolInfo.currentTick = tick;
            poolInfo.liquidityVolumeGrowth += liquidityVolumeGrowth;
            poolInfo.unSettlementAmount += tradeVolume;
            poolInfo.lastSettlementBlock = block
                .number
                .div(settlementBlock)
                .mul(settlementBlock);
            emit Snapshot(
                tradeAddress,
                tick,
                liquidityVolumeGrowth,
                tradeVolume
            );
        }
    }

    function snapshotLiquidity(
        address tradeAddress,
        int24 _tickLower,
        int24 _tickUpper
    ) external override {
        require(Address.isContract(_msgSender()));
        PoolInfo storage poolInfo = poolInfoByPoolAddress[_msgSender()];
        if (isReward[_msgSender()]) {
            UserInfo storage userInfo = userInfo[tradeAddress][_msgSender()];
            if (
                poolInfo.lastSettlementBlock.add(settlementBlock) <=
                block.number &&
                poolInfo.unSettlementAmount > 0
            ) {
                uint256 form = poolInfo.lastSettlementBlock;
                uint256 to = (form.add(settlementBlock));
                uint256 summaReward = getMultiplier(form, to)
                    .mul(poolInfo.rewardShare)
                    .div(totalRewardShare);
                poolInfo.easterEgg += summaReward.mul(easterEggPoint).div(100); //彩蛋抽成
                settlementTrade(
                    tradeAddress,
                    _msgSender(),
                    (summaReward.sub(summaReward.mul(easterEggPoint).div(100)))
                        .div(tradeShare)
                );
            }
            userInfo
                .lastRewardGrowthInside = settlementLiquidityIncentiveGrowthInPosition(
                _tickLower,
                _tickUpper,
                _msgSender()
            );
            emit SnapshotLiquidity(
                tradeAddress,
                _msgSender(),
                _tickLower,
                _tickUpper
            );
        }
    }

    function getFee(address current, uint24 fee)
        external
        view
        override
        returns (uint24)
    {
        uint24 newfee = fee;
        if (ISummaPri(priAddress).hasRole(PUBLIC_ROLE, current)) {
            newfee = fee - (fee / reduceFee);
        }
        return newfee;
    }

    function getRelation(address current)
        external
        view
        override
        returns (address)
    {
        return ISummaPri(priAddress).getRelation(current);
    }

    function getSuperFee() external view override returns (uint24) {
        return superFee;
    }

    function getPoolLength() external view returns (uint256) {
        return poolAddress.length;
    }

    // 测试用方法

    function getPoolReward(address poolAddress, uint256 blockNum)
        external
        view
        returns (uint256 lpReward, uint256 tradeReward)
    {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        uint256 form = blockNum.sub(settlementBlock);
        uint256 to = blockNum;
        uint256 summaReward = getMultiplier(form, to)
            .mul(poolInfo.rewardShare)
            .div(totalRewardShare);
        tradeReward = (
            summaReward.sub(summaReward.mul(easterEggPoint).div(100))
        ).div(tradeShare);
        lpReward = summaReward.sub(tradeReward);
    }
}