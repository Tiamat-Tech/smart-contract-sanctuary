// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import "./LockableFunction.sol";
import "./LPSwapSupport.sol";
import "../interfaces/INoBSDynamicReflector.sol";
import "./AuthorizedListExt.sol";


contract NoBSDynamicReflector is INoBSDynamicReflector, AuthorizedListExt, LPSwapSupport, LockableFunction {
    using Address for address;
    using SafeMath for uint256;

    event RewardsDistributed(string rewardName, uint256 holdersProcessed, uint256 totalRewardsSent);

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    IBEP20 public rewardsToken;
    IBEP20 public controlToken;
    RewardType private rewardType;
    RewardInfo private rewardTokenInfo;
    string private defaultCurrencyName = "BNB";

    address[] private shareholders;
    mapping (address => uint256) private shareholderIndexes;
    mapping (address => bool) private isExcludedFromDividends;

    mapping (address => Share) private shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 private dividendsPerShareAccuracyFactor = 10 ** 36;
    uint256 private defaultDecimals = 10 ** 18;
    uint256 private minPeriod;

    uint256 public minDistribution;
    uint256 public currentIndex;

    constructor(address _lpRouter, address _controlToken, address _rewardsToken) payable {
        updateRouter(_lpRouter);
        maxSpendAmount = 100 ether;
        controlToken = IBEP20(payable(_controlToken));

        if(address(_rewardsToken) == address(0)){
            rewardType = RewardType.CURRENCY;
            rewardTokenInfo.name = defaultCurrencyName;
            rewardTokenInfo.rewardAddress = address(0);
            rewardTokenInfo.decimals = defaultDecimals;
            minDistribution = defaultDecimals.div(1000);
        } else {
            rewardType = RewardType.TOKEN;
            rewardsToken = IBEP20(_rewardsToken);
            rewardTokenInfo.name = rewardsToken.name();
            rewardTokenInfo.rewardAddress = _rewardsToken;
            rewardTokenInfo.decimals = 10 ** uint256(rewardsToken.decimals());
            minDistribution = IBEP20(_rewardsToken).totalSupply().div(10 ** 9);
        }

        isExcludedFromDividends[_controlToken] = true;
        isExcludedFromDividends[address(this)] = true;
        isExcludedFromDividends[deadAddress] = true;

        _owner = _controlToken;
    }

    function rewardCurrency() external view override returns(string memory){
        return rewardTokenInfo.name;
    }

    function enroll(address shareholder) external override {
        require(!isExcludedFromDividends[shareholder], "This address is excluded and cannot register");
        uint256 amount = controlToken.balanceOf(shareholder);
        _setShare(shareholder, amount);
    }

    function excludeFromReward(address shareholder, bool shouldExclude) external override authorized {
        isExcludedFromDividends[shareholder] = shouldExclude;
        uint256 amount = 0;
        if(!shouldExclude)
            amount = controlToken.balanceOf(shareholder);
        _setShare(shareholder, amount);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override authorized {
        minDistribution = _minDistribution;
        minPeriod = _minPeriod;
    }

    function setShares(address sendingShareholder, uint256 senderBalance, address receivingShareholder, uint256 receiverBalance) public override onlyOwner {
        _setShare(sendingShareholder, senderBalance);
        _setShare(receivingShareholder, receiverBalance);
    }

    function _setShare(address shareholder, uint256 amount) internal {
        Share memory holderShares = shares[shareholder];
        if(holderShares.amount > 0){
            _distributeDividend(shareholder, true);
        }
        if(isExcludedFromDividends[shareholder]){
            if(holderShares.amount == 0){
                return;
            } else {
                amount = 0;
            }
        }
        if(amount > 0 && holderShares.amount == 0){
            addShareholder(shareholder);
        }else if(amount == 0 && holderShares.amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(holderShares.amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(amount);
    }

    receive() external payable{
        swap();
    }

    function deposit() external payable override onlyOwner {
        swap();
    }

    function swap() private {
        if(!inSwap)
            _swap();
    }

    function _swap() private lockTheSwap {
        uint256 amount = msg.value;
        if(rewardType == RewardType.TOKEN) {
            uint256 balanceBefore = rewardsToken.balanceOf(address(this));
            swapCurrencyForTokensAdv(address(rewardsToken), address(this).balance, address(this));
            amount = rewardsToken.balanceOf(address(this)).sub(balanceBefore);
        }
        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function setRewardToCurrency(bool andSwap) external override authorized {
        require(rewardType != RewardType.CURRENCY, "Rewards already set to reflect currency");
        if(!inSwap)
            resetToCurrency(andSwap);
    }

    function resetToCurrency(bool andSwap) private lockTheSwap {
        uint256 contractBalance = rewardsToken.balanceOf(address(this));
        if(contractBalance > rewardTokenInfo.decimals && andSwap)
            swapTokensForCurrencyAdv(address(rewardsToken), contractBalance, address(this));
        rewardsToken = IBEP20(address(0));
        totalDividends = address(this).balance;
        dividendsPerShare = dividendsPerShareAccuracyFactor.mul(totalDividends).div(totalShares);

        rewardTokenInfo.name = "BNB";
        rewardTokenInfo.rewardAddress = address(0);
        rewardTokenInfo.decimals = defaultDecimals;

        rewardType = RewardType.CURRENCY;
    }

    function setRewardToToken(address _tokenAddress, bool andSwap) external override authorized {
        require(rewardType != RewardType.TOKEN || _tokenAddress != address(rewardsToken), "Rewards already set to reflect this token");
        if(!inSwap)
            resetToToken(_tokenAddress, andSwap);
    }

    function resetToToken(address _tokenAddress, bool andSwap) private lockTheSwap {
        uint256 contractBalance;
        if(rewardType == RewardType.TOKEN && andSwap){
            contractBalance = rewardsToken.balanceOf(address(this));
            if(contractBalance > rewardTokenInfo.decimals)
                swapTokensForCurrencyAdv(address(rewardsToken), contractBalance, address(this));
        }
        contractBalance = address(this).balance;
        swapCurrencyForTokensAdv(_tokenAddress, contractBalance, address(this));

        rewardsToken = IBEP20(payable(_tokenAddress));
        totalDividends = rewardsToken.balanceOf(address(this));
        dividendsPerShare = dividendsPerShareAccuracyFactor.mul(totalDividends).div(totalShares);

        rewardTokenInfo.name = rewardsToken.name();
        rewardTokenInfo.rewardAddress = _tokenAddress;
        rewardTokenInfo.decimals = 10 ** uint256(rewardsToken.decimals());

        rewardType = RewardType.TOKEN;
    }

    function _approve(address, address, uint256) internal override {
        return;
    }

    function process(uint256 gas) external override  {
        if(!locked){
            _process(gas);
        }
    }

    function _process(uint256 gas) private lockFunction returns(string memory, uint256, uint256) {
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return ("", 0, 0); }
        uint256 rewardsSent = 0;
        uint256 gasUsed = 0;
        uint256 startGas = gasleft();

        uint256 iterationIndex = currentIndex < shareholderCount ? currentIndex : 0;
        uint256 startIndex = iterationIndex;

        while(gasUsed < gas && iterationIndex < shareholderCount) {
            rewardsSent = rewardsSent.add(distributeDividend(shareholders[iterationIndex]));
            iterationIndex++;
            gasUsed = startGas.sub(gasleft());
        }
        string memory rewardName = rewardTokenInfo.name;
        currentIndex = iterationIndex >= shareholderCount ? 0 : iterationIndex;
        iterationIndex = iterationIndex.sub(startIndex);
        emit RewardsDistributed(rewardName, iterationIndex, rewardsSent);
        return (rewardName, iterationIndex, rewardsSent);
    }

    function distributeDividend(address shareholder) internal lockFunction returns(uint256 amount) {
        return _distributeDividend(shareholder, false);
    }

    function _distributeDividend(address shareholder, bool force) private returns(uint256 amount) {
        Share memory holderShares = shares[shareholder];
        if(holderShares.amount == 0){ return 0; }

        amount = getUnpaidEarnings(shareholder);
        if(amount > minDistribution || (force && amount > 0)) {
            holderShares.totalRealised = holderShares.totalRealised.add(amount);
            holderShares.totalExcluded = getCumulativeDividends(holderShares.amount);
            totalDistributed = totalDistributed.add(amount);

            if(rewardType == RewardType.TOKEN){
                rewardsToken.transfer(shareholder, amount);
            } else {
                (bool success,) = shareholder.call{value: amount}("");
                if(!success)
                    return 0;
            }
        } else {
            return 0;
        }
        shares[shareholder].totalRealised = holderShares.totalRealised;
        shares[shareholder].totalExcluded = holderShares.totalExcluded;
        return amount;
    }

    function claimDividend() override external {
        if(!locked)
            distributeDividend(msg.sender);
    }

    function claimDividendFor(address shareholder) external override authorized {
        if(!locked)
            distributeDividend(shareholder);
    }

    function getUnpaidEarnings(address shareholder) public view override returns (uint256) {
        Share memory holderShares = shares[shareholder];
        if(holderShares.amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(holderShares.amount);
        uint256 shareholderTotalExcluded = holderShares.totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }

    function getShares(address shareholder) external view override returns(uint256, uint256, uint256){
        return (shares[shareholder].amount, shares[shareholder].totalExcluded, shares[shareholder].totalRealised);
    }

    function getRewardType() external view override returns (string memory) {
        return rewardTokenInfo.name;
    }

    function _balanceOf(address) internal override view virtual returns(uint256) {
        return 0;
    }
}