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

    uint public ethRewardedNotWithdraw;
    uint private _cummEth;
    uint private _totalStakedBeforeLastDis;
    
    
    struct Transaction {
        address staker;
        uint time;
        uint amount;
        uint detailId;
    }

    Transaction[] private stakingTrans;
    
    struct Detail {
        uint detailId;
        uint amount;
        uint time;
        uint firstReward;
        uint lastWithdraw;
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

    constructor(address _tokenAddress, uint _periodTime, uint _feeUnit, uint _decimal, uint _minAmountToStake) {
        token = IERC20(_tokenAddress);
        periodTime = _periodTime;
        feeUnit = _feeUnit;
        lastDis = block.timestamp;
        decimal = _decimal;
        minAmountToStake = _minAmountToStake;

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
        periodTime = value;

        emit StakBankConfigurationChanged(msg.sender, block.timestamp);
    }

    function setFeeUnit(uint value) external onlyOwner {
        feeUnit = value;

        emit StakBankConfigurationChanged(msg.sender, block.timestamp);
    }

    function setMinAmountToStake(uint value) external onlyOwner {
        minAmountToStake = value;
        
        emit StakBankConfigurationChanged(msg.sender, block.timestamp);
    }

    function setDecimal(uint value) external onlyOwner {
        decimal = value;

        emit StakBankConfigurationChanged(msg.sender, block.timestamp);
    }


    //-------------------helper func-------------------/
    function isHolder(address holder) private view returns (bool) {
        return (_staking[holder] != 0);
    }

    function nextDistribution() public view returns (uint) {
        uint cur = block.timestamp;
        if (cur >= lastDis + periodTime) return 0;
        return (periodTime - (cur - lastDis));
    }

    function numEthToReward() public view returns (uint) {
        return ((address(this).balance) - ethRewardedNotWithdraw);
    }
   
    function createNewTransaction(address user, uint current, uint amount) private {
        _numberStake[user] ++;
        Detail memory detail = Detail(_numberStake[user], amount, current, 0, 0, false);
        _eStaker[user].push(detail);
        _posDetail[user][_numberStake[user]] = _eStaker[user].length;
        Transaction memory t = Transaction(user, current, amount, _numberStake[user]);
        stakingTrans.push(t);
    }

    function isUnstaked(address user, uint idStake) private view returns (bool) {
        return (_posDetail[user][idStake] == 0);
    }

    //-------------------staking--------------------/
    function stake(uint amount) public payable {
        require(amount != 0, "Stake amount must be positive");
        require(msg.sender != owner, "Owner cannot be staker");
        require(amount >= minAmountToStake, "Need to stake more token");

        uint current = block.timestamp;
        uint platformFee = amount.mul(feeUnit).div(10 ** decimal);

        require(msg.value >= platformFee);
        require(_deliverTokensFrom(msg.sender, address(this), amount), "Failed to transfer from staker to StakBank");

        _staking[msg.sender] = _staking[msg.sender].add(amount);

        createNewTransaction(msg.sender, current, amount);

        address payable admin = address(uint(address(owner)));
        admin.transfer(platformFee);

        emit UserStaked(msg.sender, amount, current);
    }

    function stakingOf(address user) public view returns (uint) {
        return (_staking[user]);
    }

    function unstakeId(address sender, uint idStake) private {
        uint _posIdStake = _posDetail[sender][idStake] - 1;
        Detail memory detail = _eStaker[sender][_posIdStake];
        uint coinNum = detail.amount;

        _deliverTokens(sender, coinNum);

        _staking[sender] -= coinNum;
        _eStaker[sender][_posIdStake] = _eStaker[sender][_eStaker[sender].length - 1];
        _posDetail[sender][_eStaker[sender][_posIdStake].detailId] = _posIdStake + 1;
        _eStaker[sender].pop();

        delete _posDetail[sender][idStake];
    }

    function unstakeWithId(uint idStake) public {
        require(isHolder(msg.sender), "Not a Staker");
        require(_eStaker[msg.sender].length > 1, "Cannot unstake the last with this method");
        require(!isUnstaked(msg.sender, idStake), "idStake unstaked");

        uint _posIdStake = _posDetail[msg.sender][idStake] - 1;
        Detail memory detail = _eStaker[msg.sender][_posIdStake];
        uint reward = 0;

        if (detail.isOldCoin) {
            _totalStakedBeforeLastDis = _totalStakedBeforeLastDis.sub(detail.amount);
            reward = _cummEth.sub(detail.lastWithdraw);
            reward = reward.mul(detail.amount);
            reward = reward.add(detail.firstReward);
            address payable staker = address(uint160(address(msg.sender)));
            staker.transfer(reward);
            ethRewardedNotWithdraw = ethRewardedNotWithdraw.sub(reward);
        }

        unstakeId(msg.sender, idStake);

        emit UserUnstakedWithId(msg.sender, idStake, reward);
    }

    function unstakeAll() public {
        require(isHolder(msg.sender), "Not a Staker");

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

        uint totalTime = timelast.mul(_totalStakedBeforeLastDis);

        for(uint i = 0; i < stakingTrans.length; i++) {
            Transaction memory transaction = stakingTrans[i];
            if (!isHolder(transaction.staker) || isUnstaked(transaction.staker, transaction.detailId)) {
                continue;
            }
            uint newTime = (current.sub(transaction.time)).mul(transaction.amount);
            totalTime = totalTime.add(newTime);
        }

        uint ethToReward = numEthToReward();
        uint ethRewardedInThisDis = 0;

        if (totalTime > 0) {
            uint unitValue = ethToReward.div(totalTime);
            _cummEth = _cummEth.add(unitValue.mul(timelast));

            for(uint i = 0; i < stakingTrans.length; i++) {
                Transaction memory transaction = stakingTrans[i];
                if (!isHolder(transaction.staker) || isUnstaked(transaction.staker, transaction.detailId)) continue;
                uint _posIdStake = _posDetail[transaction.staker][transaction.detailId] - 1;
                _eStaker[transaction.staker][_posIdStake].lastWithdraw = _cummEth;
                uint firstTime = current - transaction.time; 
                _eStaker[transaction.staker][_posIdStake].firstReward = unitValue.mul(firstTime).mul(transaction.amount);
                _totalStakedBeforeLastDis = _totalStakedBeforeLastDis.add(transaction.amount);
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
        require(isHolder(msg.sender), "Not a Staker");

        uint userReward = 0;

        for(uint i = 0; i < _eStaker[msg.sender].length; i++) {
            Detail memory detail = _eStaker[msg.sender][i];
            if (!detail.isOldCoin) continue;
            uint addEth = (detail.amount).mul(_cummEth.sub(detail.lastWithdraw));
            addEth = addEth.add(detail.firstReward);
            userReward = userReward.add(addEth);
            _eStaker[msg.sender][i].firstReward = 0;
            _eStaker[msg.sender][i].lastWithdraw = _cummEth;
        }

        address payable staker = address(uint(address(msg.sender)));

        staker.transfer(userReward);

        ethRewardedNotWithdraw = ethRewardedNotWithdraw.sub(userReward);

        emit UserWithdrawedReward(msg.sender, userReward);
    }

    function _deliverTokensFrom(address from, address to, uint amount) private returns (bool) {
        IERC20(token).transferFrom(from, to, amount);
        return true;    
    }

    function _deliverTokens(address to, uint amount) private returns (bool) {
        IERC20(token).transfer(to, amount);
        return true;
    }

    function sendAllEthToAdmin() external onlyOwner {
        address payable admin = address(uint160(address(owner)));
        admin.transfer(address(this).balance);
    }
}