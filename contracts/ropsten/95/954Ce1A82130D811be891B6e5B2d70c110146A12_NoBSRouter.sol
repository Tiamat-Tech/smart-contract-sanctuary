// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./NoBS/utils/Ownable.sol";
import "./NoBS/interfaces/INoBSRouter.sol";
import "./NoBS/utils/NoBSContract.sol";
import "./NoBS/NoBSFactory.sol";

contract NoBSRouter is INoBSRouter, Ownable {

    INoBSFactory public noBSFactory;
    address payable private feeReceiver;
    uint256 public standardFee;
    uint256 public standardFeeDivisor;
    address public networkLPRouter;

    constructor(address owner, address _feeReceiver, address _lpRouter) public Ownable() {
        feeReceiver = payable(_feeReceiver);
        // 0.15%
        standardFee = 15;
        standardFeeDivisor = 10000;
        networkLPRouter = _lpRouter;
        _owner = owner;
        INoBSFactory _noBSFactory = new NoBSFactory(address(this), _lpRouter, _feeReceiver, standardFee, standardFeeDivisor);
        noBSFactory = _noBSFactory;
    }

    function setFeeReceiver(address _feeReceiver) external override onlyOwner {
        feeReceiver = payable(_feeReceiver);
    }

    function setFactory(address _factory) external onlyOwner {
        noBSFactory = INoBSFactory(_factory);
    }

    function transferStuckCurrency(address destination) external onlyOwner {
        destination.call{value: address(this).balance}("");
    }

    function transferStuckToken(address _destination, address _token) external onlyOwner {
        IBEP20 token = IBEP20(_token);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(_destination, balance);
    }

    function setRoutingFee(uint256 _setFee, uint256 _setFeeDivisor) external override onlyOwner {
        standardFee = _setFee;
        standardFeeDivisor = _setFeeDivisor;
        noBSFactory.setRoutingFee(_setFee, _setFeeDivisor);
    }

    function updateLPRouter(address _lpRouter) external override onlyOwner {
        networkLPRouter = _lpRouter;
        noBSFactory.updateLPRouter(_lpRouter);
    }

    // Getters
    function factory() external view override returns(address) {
        return address(noBSFactory);
    }

    function getReflector() external view override returns(address) {
        return getReflectorFor(_msgSender());
    }

    function getReflectorFor(address tokenAddress) public view override returns(address) {
        return getReflectorAtIndexFor(tokenAddress, 0);
    }

    function reflectorAtIndex(uint256 index) external view override returns(address) {
        return getReflectorAtIndexFor(_msgSender(), index);
    }

    function getReflectorAtIndexFor(address tokenAddress, uint256 index) public view override returns(address) {
        return noBSFactory.getReflector(tokenAddress, index);
    }

    // Factory Interactions
    function createReflector(address tokenToReflect) external override returns(address) {
        return noBSFactory.createReflector(_msgSender(), tokenToReflect);
    }

    function createAdditionalReflector(address tokenToReflect) external override returns(address) {
        return noBSFactory.createAdditionalReflector(_msgSender(), tokenToReflect);
    }

    // Reflection interactions
    function getShares(address shareholder) external view override returns(uint256 amount, uint256 totalExcluded, uint256 totalRealised) {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        return INoBSDynamicReflector(_reflector).getShares(shareholder);
    }

    function deposit() external payable override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).deposit{value: msg.value}();
    }

    function enroll(address shareholder) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).enroll(shareholder);
    }

    function claimDividendFor(address shareholder) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).claimDividendFor(shareholder);
    }

    function process(uint256 gas) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).process(gas);
    }

    function getSharesForReflector(address reflector, address shareholder) external view override returns(uint256 amount, uint256 totalExcluded, uint256 totalRealised) {
        return INoBSDynamicReflector(reflector).getShares(shareholder);
    }

    function depositForReflector(address reflector) external override payable {
        INoBSDynamicReflector(reflector).deposit{value: msg.value}();
    }

    function enrollForReflector(address reflector, address shareholder) external override {
        INoBSDynamicReflector(reflector).enroll(shareholder);
    }

    function claimDividendForHolderForReflector(address reflector, address shareholder) external override {
        INoBSDynamicReflector(reflector).claimDividendFor(shareholder);
    }

    function processForReflector(address reflector, uint256 gas) external override {
        INoBSDynamicReflector(reflector).process(gas);
    }

    function setShare(address shareholder, uint256 amount) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).setShare(shareholder, amount);
    }

    function setShareForReflector(address reflector, address shareholder, uint256 amount) external override {
        INoBSDynamicReflector(reflector).setShare(shareholder, amount);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setRewardToCurrency(bool andSwap) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).setRewardToCurrency(andSwap);
    }

    function setRewardToToken(address _tokenAddress, bool andSwap) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).setRewardToToken(_tokenAddress, andSwap);
    }

    function rewardCurrency() external view override returns(string memory) {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        return INoBSDynamicReflector(_reflector).rewardCurrency();
    }

    function updateGasForTransfers(uint256 gasForTransfers) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).updateGasForTransfers(gasForTransfers);
    }

    function getUnpaidEarnings(address shareholder) external view override returns (uint256) {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        return INoBSDynamicReflector(_reflector).getUnpaidEarnings(shareholder);
    }

    function setDistributionCriteriaForReflector(address reflector, uint256 _minPeriod, uint256 _minDistribution) external override {
        INoBSDynamicReflector(reflector).setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setRewardToCurrencyForReflector(address reflector, bool andSwap) external override {
        INoBSDynamicReflector(reflector).setRewardToCurrency(andSwap);
    }

    function setRewardToTokenForReflector(address reflector, address _tokenAddress, bool andSwap) external override {
        INoBSDynamicReflector(reflector).setRewardToToken(_tokenAddress, andSwap);
    }

    function rewardCurrencyForReflector(address reflector) external view override returns (string memory) {
        return INoBSDynamicReflector(reflector).rewardCurrency();
    }

    function updateGasForTransfersForReflector(address reflector, uint256 gasForTransfers) external override {
        INoBSDynamicReflector(reflector).updateGasForTransfers(gasForTransfers);
    }

    function getUnpaidEarningsForReflector(address reflector, address shareholder) external view override returns (uint256) {
        return INoBSDynamicReflector(reflector).getUnpaidEarnings(shareholder);
    }

    function excludeFromReward(address shareholder, bool shouldExclude) external override {
        address _reflector = noBSFactory.getReflectorFor(_msgSender());
        INoBSDynamicReflector(_reflector).excludeFromReward(shareholder, shouldExclude);
    }

    function excludeFromRewardForReflector(address reflector, address shareholder, bool shouldExclude) external override {
        INoBSDynamicReflector(reflector).excludeFromReward(shareholder, shouldExclude);
    }

    // Reflection Settings
    function updateExcludedFromFeesByRouter(address reflector, bool _shouldExcludeContractFromFees) external onlyOwner {
        INoBSContract(reflector).updateExcludedFromFeesByRouter(_shouldExcludeContractFromFees);
    }
}