// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';
import '@pancakeswap/pancake-swap-lib/contracts/GSN/Context.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import "./interfaces/IDividendDistributor.sol";
import "./utils/LPSwapSupport.sol";

contract DividendDistributor is IDividendDistributor, LPSwapSupport {
    using Address for address;
    using SafeMath for uint256;

    address _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    IBEP20 public rewardsToken;
    RewardType public rewardType;

    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;
    mapping (address => bool) isExcludedFromDividends;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    uint256 public minPeriod = 15 * 60;
    uint256 public minDistribution = 10 ** 9;

    uint256 currentIndex;

    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    constructor (address superFuel, address _router, address _rewardsToken) public {
        updateRouter(_router);
        minSwapAmount = 0;
        maxSwapAmount = 100 ether;

        if(_rewardsToken == address(0)){
            rewardType = RewardType.CURRENCY;
        } else {
            rewardType = RewardType.TOKEN;
            rewardsToken = IBEP20(payable(_rewardsToken));
        }
        isExcludedFromDividends[superFuel] = true;
        isExcludedFromDividends[address(this)] = true;
        isExcludedFromDividends[deadAddress] = true;
        _owner = superFuel;
    }

    function excludeFromReward(address shareholder, bool shouldExclude) external override onlyOwner {
        isExcludedFromDividends[shareholder] = shouldExclude;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyOwner {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address shareholder, uint256 amount) external override onlyOwner {
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }

        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    receive() external payable{
        if(!inSwap)
            swap();
    }

    function deposit() external payable override onlyOwner {
        if(!inSwap)
            swap();
    }

    function swap() lockTheSwap private {
        uint256 amount;
        if(rewardType == RewardType.TOKEN) {
            uint256 contractBalance = address(this).balance;
            uint256 balanceBefore = rewardsToken.balanceOf(address(this));

            swapCurrencyForTokensAdv(address(rewardsToken), contractBalance, address(this));

            amount = rewardsToken.balanceOf(address(this)).sub(balanceBefore);
        } else {
            amount = msg.value;
        }

        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function setRewardToCurrency() external override onlyOwner{
        require(rewardType != RewardType.CURRENCY, "Rewards already set to reflect currency");
        require(!inSwap, "Contract engaged in swap, unable to change rewards");
        resetToCurrency();
    }

    function resetToCurrency() private lockTheSwap {
        uint256 contractBalance = rewardsToken.balanceOf(address(this));
        swapTokensForCurrencyAdv(address(rewardsToken), contractBalance, address(this));
        rewardsToken = IBEP20(0);
        totalDividends = address(this).balance;
        dividendsPerShare = dividendsPerShareAccuracyFactor.mul(totalDividends).div(totalShares);
        rewardType = RewardType.CURRENCY;
    }

    function setRewardToToken(address _tokenAddress) external override onlyOwner{
        require(rewardType != RewardType.TOKEN || _tokenAddress != address(rewardsToken), "Rewards already set to reflect this token");
        require(!inSwap, "Contract engaged in swap, unable to change rewards");
        resetToToken(_tokenAddress);
    }

    function resetToToken(address _tokenAddress) private lockTheSwap {
        uint256 contractBalance;
        if(rewardType == RewardType.TOKEN){
            contractBalance = rewardsToken.balanceOf(address(this));
            swapTokensForCurrencyAdv(address(rewardsToken), contractBalance, address(this));
        }
        contractBalance = address(this).balance;
        swapCurrencyForTokensAdv(_tokenAddress, contractBalance, address(this));

        rewardsToken = IBEP20(payable(_tokenAddress));
        totalDividends = rewardsToken.balanceOf(address(this));
        dividendsPerShare = dividendsPerShareAccuracyFactor.mul(totalDividends).div(totalShares);
        rewardType = RewardType.TOKEN;
    }

    function _approve(address, address, uint256) internal override {
        require(false);
    }

    function process(uint256 gas) external override onlyOwner {
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return; }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
        && getUnpaidEarnings(shareholder) > minDistribution && !isExcludedFromDividends[shareholder];
    }

    function distributeDividend(address shareholder) internal {
        if(shares[shareholder].amount == 0 || isExcludedFromDividends[shareholder]){ return; }

        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0){
            totalDistributed = totalDistributed.add(amount);
            if(rewardType == RewardType.TOKEN){
                rewardsToken.transfer(shareholder, amount);
            } else {
                shareholder.call{value: amount}("");
            }
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }

    function claimDividend() external {
        distributeDividend(msg.sender);
    }

    function claimDividendFor(address shareholder) external override onlyOwner {
        distributeDividend(shareholder);
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

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
}