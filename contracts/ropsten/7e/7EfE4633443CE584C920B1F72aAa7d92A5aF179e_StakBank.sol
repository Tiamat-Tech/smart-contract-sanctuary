//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.8.0;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./IERC20.sol";

contract StakBank is Ownable {
    using SafeMath for uint;
    IERC20 public token;

    mapping(address => uint) private _staking;
    
    uint public periodTime;
    uint public feeUnit;
    uint public minAmountToStake;
    uint public lastDis;
    uint public decimal;
    uint public minEthNeededToReward; // 0.0006 eth =  600000000000000 wei = (10^9 / 0.0001) * 60(second | minute) -> pool can hold max 1 billion JST
    uint public ethRewardedNotWithdraw;
    uint public totalStaked;

    uint private unitCoinToDivide; // 1e14 = 100000000000000 = 0.0001 JST | Number of staked (JST) coin to be rewarded = 0.0001 * N
    uint private _cummEth;
    uint private _totalStakedBeforeLastDis;

    struct Transaction {
        address staker;
        uint timestamp;
        uint coinToCalcReward;
        uint detailId;
    }

    Transaction[] private stakingTrans;
    
    struct Detail {
        uint detailId;
        uint stakedAmount;
        uint coinToCalcReward;
        uint ethFirstReward;
        uint cummEthLastWithdraw;
        bool isOldCoin;
    }

    mapping(address => Detail[]) private _eStaker;
    mapping(address => mapping(uint => uint)) private _posDetail;
    mapping(address => uint) private _numberStake;
    
    event UserStaked(address indexed user, uint amount, uint timestamp);
    event UserUnstakedWithId(address indexed user, uint indexed detailId, uint rewardAmount);
    event UserUnstakedAll(address indexed user);
    event AdminDistributeReward(uint ethToReward, uint ethRewardedInThisDis);
    event UserWithdrawedReward(address indexed user, uint rewardAmount);
    event StakBankConfigurationChanged(address indexed changer, uint timestamp);

    constructor(address _tokenAddress, uint _periodTime, uint _feeUnit, uint _decimal) {
        token = IERC20(_tokenAddress);
        periodTime = _periodTime;
        feeUnit = _feeUnit;
        minAmountToStake = 100000000000000;
        lastDis = block.timestamp;
        decimal = _decimal;
        minEthNeededToReward = 600000000000000;
        totalStaked = 0;

        unitCoinToDivide = 100000000000000;
        ethRewardedNotWithdraw = 0;
        _cummEth = 0;
        _totalStakedBeforeLastDis = 0;
    }

    receive() external payable {

    }

    fallback() external payable {

    }

    //------------------ setter func-------------------/
    function setPeriodTime(uint value) external onlyOwner {
        require(value > 0, "Minimum time to next distribution must be positive number");

        periodTime = value;

        emit StakBankConfigurationChanged(msg.sender, block.timestamp);
    }

    function setFeeUnit(uint value) external onlyOwner {
        feeUnit = value;

        emit StakBankConfigurationChanged(msg.sender, block.timestamp);
    }

    function setDecimal(uint value) external onlyOwner {
        decimal = value;

        emit StakBankConfigurationChanged(msg.sender, block.timestamp);
    }

    function setMinAmountToStake(uint value) external onlyOwner {
        require(value >= unitCoinToDivide, "Lower than 0.0001 JST");

        minAmountToStake = value;
        
        emit StakBankConfigurationChanged(msg.sender, block.timestamp);
    }

    //-------------------helper public func-------------------/
    
    function nextDistribution() public view returns (uint) {
        uint cur = block.timestamp;
        if (cur >= lastDis + periodTime) return 0;
        return (periodTime - (cur - lastDis));
    }

    function numEthToReward() public view returns (uint) {
        return ((address(this).balance) - ethRewardedNotWithdraw);
    }

    function feeCalculator(uint amount) public view returns (uint) {
        uint remainder = amount % unitCoinToDivide;
        amount = amount.sub(remainder);
        uint platformFee = amount.mul(feeUnit).div(10 ** decimal);
        return platformFee;
    }

    //-------------------staking--------------------/
    function stake(uint stakedAmount) public payable {
        require(msg.sender != owner, "Owner cannot stake");
        require(stakedAmount >= minAmountToStake, "Need to stake more token");
        require(totalStaked + stakedAmount <= (10 ** 27), "Reached limit coin in pool");

        uint platformFee = feeCalculator(stakedAmount);

        require(msg.value >= platformFee);
        require(_deliverTokensFrom(msg.sender, address(this), stakedAmount), "Failed to transfer from staker to StakBank");
        
        uint current = block.timestamp;

        _staking[msg.sender] = _staking[msg.sender].add(stakedAmount);
        totalStaked = totalStaked.add(stakedAmount);

        uint remainder = stakedAmount % unitCoinToDivide;
        uint coinToCalcReward = stakedAmount - remainder;

        _createNewTransaction(msg.sender, current, stakedAmount, coinToCalcReward);

        address payable admin = address(uint(address(owner)));
        admin.transfer(platformFee);

        emit UserStaked(msg.sender, stakedAmount, current);
    }

    function stakingOf(address user) public view returns (uint) {
        return (_staking[user]);
    }

    function unstakeId(address sender, uint idStake) private {
        uint _posIdStake = _posDetail[sender][idStake] - 1;
        Detail memory detail = _eStaker[sender][_posIdStake];
        uint coinNum = detail.stakedAmount;

        _deliverTokens(sender, coinNum);

        _staking[sender] = _staking[sender].sub(coinNum);
        _eStaker[sender][_posIdStake] = _eStaker[sender][_eStaker[sender].length - 1];
        _posDetail[sender][_eStaker[sender][_posIdStake].detailId] = _posIdStake + 1;
        _eStaker[sender].pop();

        delete _posDetail[sender][idStake];
    }

    function unstakeWithId(uint idStake) public {
        require(_isHolder(msg.sender), "Not a Staker");
        require(_eStaker[msg.sender].length > 1, "Cannot unstake the last with this method");
        require(!_isUnstaked(msg.sender, idStake), "idStake unstaked");

        uint _posIdStake = _posDetail[msg.sender][idStake] - 1;
        Detail memory detail = _eStaker[msg.sender][_posIdStake];
        uint reward = 0;

        if (detail.isOldCoin) {
            _totalStakedBeforeLastDis = _totalStakedBeforeLastDis.sub(detail.coinToCalcReward);
            reward = _cummEth.sub(detail.cummEthLastWithdraw);

            uint numUnitCoin = (detail.coinToCalcReward).div(unitCoinToDivide);
            reward = reward.mul(numUnitCoin);
            reward = reward.add(detail.ethFirstReward);

            address payable staker = address(uint160(address(msg.sender)));
            staker.transfer(reward);

            ethRewardedNotWithdraw = ethRewardedNotWithdraw.sub(reward);
        }

        unstakeId(msg.sender, idStake);

        emit UserUnstakedWithId(msg.sender, idStake, reward);
    }

    function unstakeAll() public {
        require(_isHolder(msg.sender), "Not a Staker");

        withdrawReward();

        for(uint i = 0; i < _eStaker[msg.sender].length; i++) {
            unstakeId(msg.sender, _eStaker[msg.sender][i].detailId);
        }

        delete _eStaker[msg.sender];
        delete _numberStake[msg.sender];

        emit UserUnstakedAll(msg.sender);
    }

    //-------------------reward-------------------/
    function rewardDistribution() public onlyOwner {
        uint current = block.timestamp;
        uint timelast = current.sub(lastDis);
        
        require(timelast >= periodTime, "Too soon to trigger reward distribution");

        uint ethToReward = numEthToReward();

        if (ethToReward < minEthNeededToReward) { // --> not distribution when too few eth
            _notEnoughEthToReward();
            return;
        }
        
        uint unitTime;
        (timelast, unitTime) = _changeToAnotherUnitTime(timelast);
        
        uint UnitCoinNumberBeforeLastDis = _totalStakedBeforeLastDis.div(unitCoinToDivide);
        uint totalTime = timelast.mul(UnitCoinNumberBeforeLastDis);

        for(uint i = 0; i < stakingTrans.length; i++) {
            Transaction memory transaction = stakingTrans[i];

            if (!_isHolder(transaction.staker) || _isUnstaked(transaction.staker, transaction.detailId)) {
                continue;
            }

            uint numTimeWithStandardUnit = (current.sub(transaction.timestamp)).div(unitTime);
            uint numUnitCoin = (transaction.coinToCalcReward).div(unitCoinToDivide);

            totalTime = totalTime.add(numUnitCoin.mul(numTimeWithStandardUnit));
        }

        uint ethRewardedInThisDis = 0;

        if (totalTime > 0) {
            uint unitValue = ethToReward.div(totalTime);
            _cummEth = _cummEth.add(unitValue.mul(timelast));

            for(uint i = 0; i < stakingTrans.length; i++) {
                Transaction memory transaction = stakingTrans[i];

                if (!_isHolder(transaction.staker) || _isUnstaked(transaction.staker, transaction.detailId)) {
                    continue;
                }

                uint _posIdStake = _posDetail[transaction.staker][transaction.detailId] - 1;
                _eStaker[transaction.staker][_posIdStake].cummEthLastWithdraw = _cummEth;
                
                uint numTimeWithStandardUnit = (current.sub(transaction.timestamp)).div(unitTime);
                uint numUnitCoin = (transaction.coinToCalcReward).div(unitCoinToDivide);

                _eStaker[transaction.staker][_posIdStake].ethFirstReward = unitValue.mul(numUnitCoin).mul(numTimeWithStandardUnit);

                _totalStakedBeforeLastDis = _totalStakedBeforeLastDis.add(transaction.coinToCalcReward);
                _eStaker[transaction.staker][_posIdStake].isOldCoin = true;
            }

            delete stakingTrans;
            ethRewardedInThisDis = unitValue.mul(totalTime);
            ethRewardedNotWithdraw = ethRewardedNotWithdraw.add(ethRewardedInThisDis);
        }

        lastDis = block.timestamp;

        emit AdminDistributeReward(ethToReward, ethRewardedInThisDis);
    }

    function withdrawReward() public {
        require(_isHolder(msg.sender), "Not a Staker");

        uint userReward = 0;

        for(uint i = 0; i < _eStaker[msg.sender].length; i++) {
            Detail memory detail = _eStaker[msg.sender][i];

            if (!detail.isOldCoin) {
                continue;
            }

            uint numUnitCoin = (detail.coinToCalcReward).div(unitCoinToDivide);

            uint addEth = (numUnitCoin).mul(_cummEth.sub(detail.cummEthLastWithdraw));
            addEth = addEth.add(detail.ethFirstReward);
            userReward = userReward.add(addEth);

            _eStaker[msg.sender][i].ethFirstReward = 0;
            _eStaker[msg.sender][i].cummEthLastWithdraw = _cummEth;
        }

        address payable staker = address(uint(address(msg.sender)));

        staker.transfer(userReward);

        ethRewardedNotWithdraw = ethRewardedNotWithdraw.sub(userReward);

        emit UserWithdrawedReward(msg.sender, userReward);
    }

    //---------------------------------------------------------------------------

    function _createNewTransaction(address user, uint current, uint stakedAmount, uint coinToCalcReward) private {
        _numberStake[user] ++;

        Detail memory detail = Detail(_numberStake[user], stakedAmount, coinToCalcReward, 0, 0, false);
        _eStaker[user].push(detail);

        _posDetail[user][_numberStake[user]] = _eStaker[user].length;

        Transaction memory t = Transaction(user, current, coinToCalcReward, _numberStake[user]);
        stakingTrans.push(t);
    }

    function _isHolder(address holder) private view returns (bool) {
        return (_staking[holder] != 0);
    }

    function _isUnstaked(address user, uint idStake) private view returns (bool) {
        return (_posDetail[user][idStake] == 0);
    }

    function _deliverTokensFrom(address from, address to, uint amount) private returns (bool) {
        IERC20(token).transferFrom(from, to, amount);
        return true;    
    }

    function _deliverTokens(address to, uint amount) private returns (bool) {
        IERC20(token).transfer(to, amount);
        return true;
    }

    function _changeToAnotherUnitTime(uint second) private pure returns (uint, uint) {
        uint unitTime = 1;
        if (second <= 60) return (second, 1);

        unitTime = unitTime.mul(60);
        uint minute = second / unitTime;
        if (minute <= 60) return (minute, unitTime);

        unitTime = unitTime.mul(60);
        uint hour = second / unitTime;
        if (hour <= 24) return (hour, unitTime);

        unitTime = unitTime.mul(24);
        uint day = second / unitTime;
        if (day <= 30) return (day, unitTime);

        unitTime = unitTime.mul(30);
        uint month = second / unitTime;
        if (month <= 12) return (month, unitTime);

        unitTime = unitTime.mul(12);
        uint year = second / unitTime;
        if (year > 50) year = 50;
        return (year, unitTime);
    } 

    function sendAllEthToAdmin() external onlyOwner {
        address payable admin = address(uint160(address(owner)));
        admin.transfer(address(this).balance);
    }

    function _notEnoughEthToReward() private {
        for(uint i = 0; i < stakingTrans.length; i++) {
            Transaction memory transaction = stakingTrans[i];

            if (!_isHolder(transaction.staker) || _isUnstaked(transaction.staker, transaction.detailId)) {
                continue;
            }

            uint _posIdStake = _posDetail[transaction.staker][transaction.detailId] - 1;
            _eStaker[transaction.staker][_posIdStake].cummEthLastWithdraw = _cummEth;

            _totalStakedBeforeLastDis = _totalStakedBeforeLastDis.add(transaction.coinToCalcReward);
            _eStaker[transaction.staker][_posIdStake].isOldCoin = true;
        }

        delete stakingTrans;
    }

}