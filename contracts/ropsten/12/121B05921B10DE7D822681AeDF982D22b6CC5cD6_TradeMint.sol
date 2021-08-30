pragma solidity >=0.7.6;
pragma abicoder v2;

import '../libraries/SafeMath.sol'; 
import '../libraries/Address.sol'; 
import '../libraries/trademint/PoolAddress.sol'; 
import '../interface/IERC20.sol'; 
import '../interface/ITokenIssue.sol'; 
import '../libraries/SafeERC20.sol'; 
import '../interface/trademint/ISummaSwapV3Manager.sol'; 
import '../interface/trademint/ITradeMint.sol'; 
import '../libraries/Context.sol'; 
import '../libraries/Owned.sol'; 
import '../libraries/FixedPoint128.sol';
import '../libraries/FullMath.sol';
import '../interface/ISummaPri.sol'; 


contract TradeMint is ITradeMint,Context,Owned{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    
    ITokenIssue public tokenIssue;
    
    ISummaSwapV3Manager public iSummaSwapV3Manager;

    uint256 public totalIssueRate = 0.1 * 10000;
    
    uint256 public settlementBlock;
    
    mapping(address => bool) public  isReward; 
    
    uint256 public totalRewardShare;
    
    address public factory;
    
    uint256 public tradeShare; 

    bytes32 public constant PUBLIC_ROLE = keccak256("PUBLIC_ROLE");

    uint24 public reduceFee;

    uint24 private superFee;
    
    struct TickInfo{
        uint256 liquidityVolumeGrowthOutside; 
        
        uint256 liquidityIncentiveGrowthOutside;
        
        uint256 settlementBlock;
    }
    
    
    struct PoolInfo {
        uint256 lastSettlementBlock; 
        
        mapping(int24 => TickInfo)  ticks;  
        
        uint256 liquidityVolumeGrowth;
        
        uint256 liquidityIncentiveGrowth;
    
        uint256 rewardShare;
    
        int24 currentTick; 
        
        uint256 unSettlementAmount; 
        
        mapping(uint256 => uint256)  blockSettlementVolume; 
        
        address poolAddress;
        
        mapping(uint256 => uint256)  tradeSettlementAmountGrowth; 
                                                                 
        
    }
    
    
    struct UserInfo {
        uint256 tradeSettlementedAmount;    
        uint256 tradeUnSettlementedAmount;
        
        uint256 lastTradeBlock; 
        uint256 lastRewardGrowthInside; 
        
    }
   
    address[] public poolAddress; 
    
    
    uint256 public pledgeRate; 

    uint256 public minPledge; 
    
    address public summaAddress; 

    address public priAddress;
    
    mapping(address => mapping(address => UserInfo)) public  userInfo;  
    
    
    mapping(address => PoolInfo) public  poolInfoByPoolAddress; 
    
    uint256 public lastWithdrawBlock; 
    
    
    event Cross(int24 _tick,int24 _nextTick);
    
    event Snapshot(address tradeAddress,int24 tick,uint256 liquidityVolumeGrowth,uint256 tradeVolume);
    
    event SnapshotLiquidity(address tradeAddress,address poolAddress,int24 _tickLower,int24 _tickUpper);
    

    function setTokenIssue(ITokenIssue _tokenIssue) public onlyOwner {
        tokenIssue = _tokenIssue;
    }

    function setISummaSwapV3Manager(ISummaSwapV3Manager _ISummaSwapV3Manager) public onlyOwner {
        iSummaSwapV3Manager = _ISummaSwapV3Manager;
    }

    function setTotalIssueRate(uint256 _totalIssueRate) public onlyOwner {
        totalIssueRate = _totalIssueRate;
    }
    function setSettlementBlock(uint256 _settlementBlock) public onlyOwner {
        settlementBlock = _settlementBlock;
    }
    function setFactory(address _factory) public onlyOwner {
        factory = _factory;
    }
    function setTradeShare(uint256 _tradeShare) public onlyOwner {
        tradeShare = _tradeShare;
    }
    function setPledgeRate(uint256 _pledgeRate) public onlyOwner {
        pledgeRate = _pledgeRate;
    }
    function setMinPledge(uint256 _minPledge) public onlyOwner {
        minPledge = _minPledge;
    }
    function setSummaAddress(address _summaAddress) public onlyOwner {
        summaAddress = _summaAddress;
    }
    function setPriAddress(address _priAddress) public onlyOwner {
        priAddress = _priAddress;
    }
    function setReduceFee(uint24 _reduceFee) public onlyOwner {
        reduceFee = _reduceFee;
    }
    function setSuperFee(uint24 _superFee) public onlyOwner {
        superFee = _superFee;
    }
    function enableReward(address _poolAddress,bool _isReward,uint256 _rewardShare) public onlyOwner {
       if(_isReward){
            PoolInfo storage _poolInfo = poolInfoByPoolAddress[_poolAddress];
            _poolInfo.lastSettlementBlock = block.number.div(settlementBlock).mul(settlementBlock);
            _poolInfo.poolAddress = _poolAddress;
            _poolInfo.rewardShare = _rewardShare;
            totalRewardShare += _rewardShare;
            poolAddress.push(_poolAddress);
        }else{
            require(isReward[_poolAddress],"pool is not reward");
            PoolInfo storage _poolInfo = poolInfoByPoolAddress[_poolAddress];
            totalRewardShare -= _poolInfo.rewardShare;
            _poolInfo.rewardShare = 0;
        }
        isReward[_poolAddress] = _isReward;
        massUpdatePools();

    }
    function enableReward(address token0,address token1,uint24 fee,bool _isReward,uint256 _rewardShare) public onlyOwner {
        address _poolAddress = PoolAddress.computeAddress(factory,token0,token1,fee);
        if(_isReward){
            PoolInfo storage _poolInfo = poolInfoByPoolAddress[_poolAddress];
            _poolInfo.lastSettlementBlock = block.number.div(settlementBlock).mul(settlementBlock);
            _poolInfo.poolAddress = _poolAddress;
            _poolInfo.rewardShare = _rewardShare;
            totalRewardShare += _rewardShare;
            poolAddress.push(_poolAddress);
        }else{
            require(isReward[_poolAddress],"pool is not reward");
            PoolInfo storage _poolInfo = poolInfoByPoolAddress[_poolAddress];
            totalRewardShare -= _poolInfo.rewardShare;
            _poolInfo.rewardShare = 0;
        }
        isReward[_poolAddress] = _isReward;
        massUpdatePools();
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
        if(poolInfo.lastSettlementBlock.add(settlementBlock) <= block.number  && poolInfo.unSettlementAmount >0){
                uint256 form = poolInfo.lastSettlementBlock;
                uint256 to =(form.add(settlementBlock));
                uint256 multiplier = getMultiplier(form, to);
                uint256 summaReward = multiplier.mul(poolInfo.rewardShare).div(totalRewardShare).div(tradeShare);
                settlementTrade(poolInfo.poolAddress,summaReward);
                settlementPoolNewLiquidityIncentiveGrowth(poolInfo.poolAddress);
        }
    }
    
    
    function pendingSumma(address userAddress) public view returns(uint256){
        uint256 amount = 0; 
        uint256 length = poolAddress.length;  
        for (uint256 pid = 0; pid < length; ++pid) { 
            address _poolAddress = poolAddress[pid];
            PoolInfo storage poolInfo = poolInfoByPoolAddress[_poolAddress];
            UserInfo storage userInfo = userInfo[userAddress][poolAddress[pid]]; 
            if(userInfo.lastTradeBlock != 0){
                if(userInfo.lastTradeBlock < poolInfo.lastSettlementBlock){ 
                    
                    amount += userInfo.tradeUnSettlementedAmount.mul(poolInfo.tradeSettlementAmountGrowth[(userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(settlementBlock)]);
                }else if((userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(settlementBlock) <= block.number && poolInfo.unSettlementAmount >0){
                   
                    uint256 form = (userInfo.lastTradeBlock.div(settlementBlock).sub(1)).mul(settlementBlock);
                    uint256 to =(userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(settlementBlock);
                    uint256 multiplier = getMultiplier(form, to);
                    uint256 summaReward = multiplier.mul(poolInfo.rewardShare).div(totalRewardShare).div(tradeShare);
                    amount += (summaReward.div(poolInfo.unSettlementAmount).mul(userInfo.tradeUnSettlementedAmount));
                }
               
                amount = amount+userInfo.tradeSettlementedAmount;
            }
            
        }
        
        uint256 balance = iSummaSwapV3Manager.balanceOf(userAddress);
        
        for (uint256 pid = 0; pid < balance; ++pid) {
           
            (,,address token0,address token1,uint24 fee,int24 tickLower,int24 tickUpper,uint128 liquidity,,,,) =iSummaSwapV3Manager.positions(iSummaSwapV3Manager.tokenOfOwnerByIndex(userAddress,pid));
            address poolAddress = PoolAddress.computeAddress(factory,token0,token1,fee);
            if(isReward[poolAddress]){ 
                uint256 userLastReward = userInfo[userAddress][poolAddress].lastRewardGrowthInside;
                uint256 liquidityIncentiveGrowthInPosition = getLiquidityIncentiveGrowthInPosition(tickLower,tickUpper,poolAddress).sub(userLastReward);
                
                amount +=  FullMath.mulDiv(
                liquidityIncentiveGrowthInPosition,
                liquidity,
                FixedPoint128.Q128);
                
               
            }
        }
       
        return amount;
    }
    function getPoolReward(address  poolAddress) internal view returns (uint256) {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
       
        uint256 form = poolInfo.lastSettlementBlock;
        uint256 to = poolInfo.lastSettlementBlock.add(settlementBlock);
        uint256 multiplier = getMultiplier(form, to);
        
        uint256 reward =  multiplier.mul(poolInfo.rewardShare).div(totalRewardShare).div(tradeShare).mul(tradeShare.sub(1));    
        return reward;
    }
    
    function getPoolReward(address  poolAddress,uint256 form,uint256 to) internal view returns (uint256) {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        uint256 multiplier = getMultiplier(form, to);
        uint256 reward =  multiplier.mul(poolInfo.rewardShare).div(totalRewardShare).div(tradeShare).mul(tradeShare.sub(1));    
        return reward;
    }
    function getLiquidityIncentiveGrowthInPosition(int24 _tickLower,int24 _tickUpper,address  poolAddress) internal view returns (uint256) {
       
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress]; 
        uint256 newLiquidityIncentiveGrowth = poolInfo.liquidityIncentiveGrowth;
        if(poolInfo.lastSettlementBlock.add(settlementBlock) <= block.number && poolInfo.unSettlementAmount >0){  
            newLiquidityIncentiveGrowth = getPoolNewLiquidityIncentiveGrowth(poolAddress);
        }
        TickInfo storage tickLower = poolInfo.ticks[_tickLower];

        uint256 newLowerLiquidityIncentiveGrowthOutside = tickLower.liquidityIncentiveGrowthOutside;
       
        if(tickLower.liquidityVolumeGrowthOutside != 0){ 
            uint256 lowerReward = getPoolReward(poolAddress,tickLower.settlementBlock.sub(settlementBlock),tickLower.settlementBlock);
            
            newLowerLiquidityIncentiveGrowthOutside = newLowerLiquidityIncentiveGrowthOutside +lowerReward.mul(tickLower.liquidityVolumeGrowthOutside).div(poolInfo.blockSettlementVolume[tickLower.settlementBlock]);
           
        }
       
        TickInfo storage tickUpper = poolInfo.ticks[_tickUpper];
        uint256 newUpLiquidityIncentiveGrowthOutside = tickUpper.liquidityIncentiveGrowthOutside;
        if(tickUpper.liquidityVolumeGrowthOutside != 0){
            uint256 upReward = getPoolReward(poolAddress,tickUpper.settlementBlock.sub(settlementBlock),tickUpper.settlementBlock);
           
            newUpLiquidityIncentiveGrowthOutside = newUpLiquidityIncentiveGrowthOutside +upReward.mul(tickUpper.liquidityVolumeGrowthOutside).div(poolInfo.blockSettlementVolume[tickUpper.settlementBlock]);
            
        }
        // calculate fee growth below
        uint256 feeGrowthBelow;
        if (poolInfo.currentTick >= _tickLower) {
           
            feeGrowthBelow = newLowerLiquidityIncentiveGrowthOutside;
        } else {
           
            feeGrowthBelow = newLiquidityIncentiveGrowth - newLowerLiquidityIncentiveGrowthOutside;
        }

       
        uint256 feeGrowthAbove;
        if (poolInfo.currentTick < _tickUpper) {
           
            feeGrowthAbove = newUpLiquidityIncentiveGrowthOutside;
        } else {
            
            feeGrowthAbove = newLiquidityIncentiveGrowth - newUpLiquidityIncentiveGrowthOutside;
        }
        
        uint256 feeGrowthInside = newLiquidityIncentiveGrowth - feeGrowthBelow - feeGrowthAbove ;
        return feeGrowthInside;
    }
    function settlementLiquidityIncentiveGrowthInPosition(int24 _tickLower,int24 _tickUpper,address  poolAddress) internal returns (uint256) {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        
        if(poolInfo.lastSettlementBlock.add(settlementBlock) <= block.number  && poolInfo.unSettlementAmount >0){
            settlementPoolNewLiquidityIncentiveGrowth(poolAddress);
        }
        
        uint256 newLiquidityIncentiveGrowth = poolInfo.liquidityIncentiveGrowth;
        if(newLiquidityIncentiveGrowth == 0){
             return 0;
        }
        TickInfo storage tickLower = poolInfo.ticks[_tickLower];
        if(poolInfo.blockSettlementVolume[tickLower.settlementBlock] >0 && tickLower.liquidityVolumeGrowthOutside>0){
            uint256 lowerReward = getPoolReward(poolAddress,tickLower.settlementBlock.sub(settlementBlock),tickLower.settlementBlock);
            tickLower.liquidityIncentiveGrowthOutside = tickLower.liquidityIncentiveGrowthOutside+lowerReward.mul(tickLower.liquidityVolumeGrowthOutside).div(poolInfo.blockSettlementVolume[tickLower.settlementBlock]);
        }
        uint256 newLowerLiquidityIncentiveGrowthOutside = tickLower.liquidityIncentiveGrowthOutside;

        TickInfo storage tickUpper = poolInfo.ticks[_tickUpper];
        
        if(poolInfo.blockSettlementVolume[tickUpper.settlementBlock] >0 && tickUpper.liquidityVolumeGrowthOutside >0){
            uint256 upReward = getPoolReward(poolAddress,tickUpper.settlementBlock.sub(settlementBlock),tickUpper.settlementBlock);
            tickUpper.liquidityIncentiveGrowthOutside = tickUpper.liquidityIncentiveGrowthOutside+upReward.mul(tickUpper.liquidityVolumeGrowthOutside).div(poolInfo.blockSettlementVolume[tickUpper.settlementBlock]);
        }
        uint256 newUpLiquidityIncentiveGrowthOutside  = tickUpper.liquidityIncentiveGrowthOutside;
        // calculate fee growth below
        uint256 feeGrowthBelow;
        if (poolInfo.currentTick >= _tickLower) {
            feeGrowthBelow = newLowerLiquidityIncentiveGrowthOutside;
        } else {
            feeGrowthBelow = newLiquidityIncentiveGrowth - newLowerLiquidityIncentiveGrowthOutside;
        }

       
        uint256 feeGrowthAbove;
        if (poolInfo.currentTick < _tickUpper) {
            feeGrowthAbove = newUpLiquidityIncentiveGrowthOutside;
        } else {
            feeGrowthAbove = newLiquidityIncentiveGrowth - newUpLiquidityIncentiveGrowthOutside;
        }
        uint256 feeGrowthInside = newLiquidityIncentiveGrowth - feeGrowthBelow - feeGrowthAbove ;
        return feeGrowthInside;
    }
    function settlementPoolNewLiquidityIncentiveGrowth(address  poolAddress) internal returns (uint256) {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        uint256 reward = getPoolReward(poolAddress);
        
        poolInfo.liquidityIncentiveGrowth += poolInfo.liquidityIncentiveGrowth+reward.mul(poolInfo.liquidityVolumeGrowth).div(poolInfo.unSettlementAmount);
        poolInfo.liquidityVolumeGrowth = 0;
      
        poolInfo.blockSettlementVolume[poolInfo.lastSettlementBlock.add(settlementBlock)] = poolInfo.unSettlementAmount;
       
        poolInfo.unSettlementAmount = 0;
        
        poolInfo.lastSettlementBlock = poolInfo.lastSettlementBlock.add(settlementBlock);
        
        return poolInfo.liquidityIncentiveGrowth;
    }
    function getPoolNewLiquidityIncentiveGrowth(address  poolAddress) internal view returns (uint256) {
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
       
        uint256 reward = getPoolReward(poolAddress);
        uint256 newLiquidityIncentiveGrowth = poolInfo.liquidityIncentiveGrowth.add(reward.mul(poolInfo.liquidityVolumeGrowth).div(poolInfo.unSettlementAmount));
        
        return newLiquidityIncentiveGrowth;
    }
    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        uint256 issueTime = tokenIssue.startIssueTime();
         if (_to < issueTime) {
                return 0;
            }
            if (_from < issueTime) {
                return getIssue(issueTime, _to).mul(totalIssueRate).div(10000);
            }
        return getIssue(issueTime, _to).sub(getIssue(issueTime, _from)).mul(totalIssueRate).div(10000);
    }
    function withdraw() public {
       
        uint256 summaReward = getMultiplier(lastWithdrawBlock,block.number);
        tokenIssue.transByContract(address(this), summaReward);
       
        uint256 amount = withdrawSettlement();
       
        uint256 pledge = amount.mul(pledgeRate).div(100);
            if(pledge < 100 * 10 ** 18){
                pledge = 100 * 10 ** 18;
            }
        require(IERC20(summaAddress).balanceOf(msg.sender)>pledge,"Insufficient pledge");
        IERC20(summaAddress).safeTransfer(address(msg.sender), amount);
    }
    function settlementTrade(address tradeAddress,address  poolAddress,uint256 summaReward) internal{
        UserInfo storage userInfo = userInfo[tradeAddress][poolAddress];
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
    
        poolInfo.tradeSettlementAmountGrowth[poolInfo.lastSettlementBlock.add(settlementBlock)] += summaReward.div(poolInfo.unSettlementAmount);
       
        userInfo.tradeSettlementedAmount += userInfo.tradeUnSettlementedAmount.mul(poolInfo.tradeSettlementAmountGrowth[(userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(settlementBlock)]);
       
        userInfo.tradeUnSettlementedAmount = 0;
       
    }
    function settlementTrade(address  poolAddress,uint256 summaReward) internal{
        PoolInfo storage poolInfo = poolInfoByPoolAddress[poolAddress];
        poolInfo.tradeSettlementAmountGrowth[poolInfo.lastSettlementBlock.add(settlementBlock)] += summaReward.div(poolInfo.unSettlementAmount);
    }
    function withdrawSettlement() internal returns(uint256){
        uint256 amount = 0; 
        uint256 length = poolAddress.length; 
        for (uint256 pid = 0; pid < length; ++pid) {
            address _poolAddress = poolAddress[pid];
            PoolInfo storage poolInfo = poolInfoByPoolAddress[_poolAddress];
            UserInfo storage userInfo = userInfo[msg.sender][poolAddress[pid]];
            
            if(userInfo.lastTradeBlock != 0){
                if(userInfo.lastTradeBlock < poolInfo.lastSettlementBlock){
                   
                    userInfo.tradeSettlementedAmount += userInfo.tradeUnSettlementedAmount.mul(poolInfo.tradeSettlementAmountGrowth[(userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(settlementBlock)]);
                    userInfo.tradeUnSettlementedAmount = 0;
                }else if((userInfo.lastTradeBlock.div(settlementBlock).add(1)).mul(settlementBlock) <= block.number && poolInfo.unSettlementAmount >0){
                    
                  
                    uint256 form = (userInfo.lastTradeBlock.div(settlementBlock)).mul(settlementBlock);
                    uint256 to =(form.add(settlementBlock));
                    uint256 multiplier = getMultiplier(form, to);
                    uint256 summaReward = multiplier.mul(poolInfo.rewardShare).div(totalRewardShare).div(tradeShare);
                    poolInfo.tradeSettlementAmountGrowth[form.add(settlementBlock)] += summaReward.div(poolInfo.unSettlementAmount);
                    
                    userInfo.tradeSettlementedAmount += userInfo.tradeUnSettlementedAmount.mul(poolInfo.tradeSettlementAmountGrowth[form.add(settlementBlock)]);
                    
                    userInfo.tradeUnSettlementedAmount = 0;
                  
                }
                amount += userInfo.tradeSettlementedAmount;
                userInfo.tradeSettlementedAmount = 0;
                
            }
            
        }
        
        uint256 balance = iSummaSwapV3Manager.balanceOf(msg.sender);

       
        
        for (uint256 pid = 0; pid < balance; ++pid) {
            (,,address token0,address token1,uint24 fee,int24 tickLower,int24 tickUpper,uint128 liquidity,,,,) =iSummaSwapV3Manager.positions(iSummaSwapV3Manager.tokenOfOwnerByIndex(msg.sender,pid));
            address poolAddress = PoolAddress.computeAddress(factory,token0,token1,fee);
            if(isReward[poolAddress]){
                uint256 newLiquidityIncentiveGrowthInPosition = settlementLiquidityIncentiveGrowthInPosition(tickLower,tickUpper,poolAddress);
                
                uint256 liquidityIncentiveGrowthInPosition = newLiquidityIncentiveGrowthInPosition.sub(userInfo[msg.sender][poolAddress].lastRewardGrowthInside);
                userInfo[msg.sender][poolAddress].lastRewardGrowthInside = newLiquidityIncentiveGrowthInPosition;
               
                amount += FullMath.mulDiv(
                liquidityIncentiveGrowthInPosition,
                liquidity,
                FixedPoint128.Q128);
            }
        }
        return amount;
    }
    
    function getIssue(uint256 _from, uint256 _to) private view returns (uint256){
        if (_to <= _from || _from <= 0) {
            return 0;
        }
        uint256 timeInterval = _to - _from;
        uint256 monthIndex = timeInterval.div(tokenIssue.MONTH_SECONDS());
        if (monthIndex < 1) {
            return timeInterval.mul(tokenIssue.issueInfo(monthIndex).div(tokenIssue.MONTH_SECONDS()));
        } else if (monthIndex < tokenIssue.issueInfoLength()) {
            uint256 tempTotal = 0;
            for (uint256 j = 0; j < monthIndex; j++) {
                tempTotal = tempTotal.add(tokenIssue.issueInfo(j));
            }
            uint256 calcAmount = timeInterval.sub(monthIndex.mul(tokenIssue.MONTH_SECONDS())).mul(tokenIssue.issueInfo(monthIndex).div(tokenIssue.MONTH_SECONDS())).add(tempTotal);
            if (calcAmount > tokenIssue.TOTAL_AMOUNT().sub(tokenIssue.INIT_MINE_SUPPLY())) {
                return tokenIssue.TOTAL_AMOUNT().sub(tokenIssue.INIT_MINE_SUPPLY());
            }
            return calcAmount;
        } else {
            return 0;
        }
    }
    
    function cross(int24 _tick,int24 _nextTick) external override{
        require(Address.isContract(_msgSender()));
        PoolInfo storage poolInfo = poolInfoByPoolAddress[_msgSender()];
        if(isReward[_msgSender()]){
            poolInfo.currentTick = _nextTick;
            TickInfo storage tick  = poolInfo.ticks[_tick];
            
            if(tick.liquidityVolumeGrowthOutside >0 ){
                uint256 reward = getPoolReward(_msgSender(),tick.settlementBlock.sub(settlementBlock),tick.settlementBlock);
                tick.liquidityIncentiveGrowthOutside = tick.liquidityIncentiveGrowthOutside+reward.mul(tick.liquidityVolumeGrowthOutside).div(poolInfo.blockSettlementVolume[tick.settlementBlock]);
            }
            
            tick.liquidityIncentiveGrowthOutside = poolInfo.liquidityIncentiveGrowth - tick.liquidityIncentiveGrowthOutside;
            tick.liquidityVolumeGrowthOutside = poolInfo.liquidityVolumeGrowth - tick.liquidityVolumeGrowthOutside;
            tick.settlementBlock = poolInfo.lastSettlementBlock.add(settlementBlock);
            emit Cross(_tick, _nextTick);
        }
    }
   
    function snapshot(address tradeAddress,int24 tick,uint256 liquidityVolumeGrowth,uint256 tradeVolume) external override {
        require(Address.isContract(_msgSender()));
        PoolInfo storage poolInfo = poolInfoByPoolAddress[_msgSender()];
        if(isReward[_msgSender()]){
            if(poolInfo.lastSettlementBlock.add(settlementBlock) <= block.number  && poolInfo.unSettlementAmount >0){
                uint256 form = poolInfo.lastSettlementBlock;
                uint256 to =(form.add(settlementBlock));
                uint256 multiplier = getMultiplier(form, to);
                uint256 summaReward = multiplier.mul(poolInfo.rewardShare).div(totalRewardShare).div(tradeShare);
                settlementTrade(tradeAddress,_msgSender(),summaReward);
                settlementPoolNewLiquidityIncentiveGrowth(_msgSender());
            }
            UserInfo storage userInfo = userInfo[tradeAddress][_msgSender()];
            userInfo.tradeUnSettlementedAmount += tradeVolume;
            userInfo.lastTradeBlock = block.number;
            poolInfo.currentTick = tick;
            poolInfo.liquidityVolumeGrowth += liquidityVolumeGrowth;
            poolInfo.unSettlementAmount += tradeVolume;
            poolInfo.lastSettlementBlock = block.number.div(settlementBlock).mul(settlementBlock);
            emit Snapshot(tradeAddress, tick, liquidityVolumeGrowth, tradeVolume);
        }
    }

    
    function snapshotLiquidity(address tradeAddress,int24 _tickLower,int24 _tickUpper) external override{
        require(Address.isContract(_msgSender()));
        PoolInfo storage poolInfo = poolInfoByPoolAddress[_msgSender()];
        if(isReward[_msgSender()]){
            UserInfo storage userInfo = userInfo[tradeAddress][_msgSender()];
            if(poolInfo.lastSettlementBlock.add(settlementBlock) <= block.number  && poolInfo.unSettlementAmount >0){
                uint256 form = poolInfo.lastSettlementBlock;
                uint256 to =(form.add(settlementBlock));
                uint256 multiplier = getMultiplier(form, to);
                uint256 summaReward = multiplier.mul(poolInfo.rewardShare).div(totalRewardShare).div(tradeShare);
                settlementTrade(tradeAddress,_msgSender(),summaReward);
            }
            userInfo.lastRewardGrowthInside = settlementLiquidityIncentiveGrowthInPosition(_tickLower,_tickUpper,_msgSender());
            
            emit SnapshotLiquidity(tradeAddress, _msgSender(), _tickLower, _tickUpper);
        }
    }

    function getFee(address current,uint24 fee) external view  override returns (uint24){
        uint24 newfee = fee;
        if(ISummaPri(priAddress).hasRole(PUBLIC_ROLE, current)){
            newfee = fee - (fee/reduceFee);
        }
        return newfee;
    }

    function getRelation(address current) external view override returns (address){ 
        return ISummaPri(priAddress).getRelation(current);
    }

    function getSuperFee() external view override returns (uint24){ 
        return superFee;
    }

    function getPoolLength() external view returns (uint256){ 
        return poolAddress.length;
    }
}