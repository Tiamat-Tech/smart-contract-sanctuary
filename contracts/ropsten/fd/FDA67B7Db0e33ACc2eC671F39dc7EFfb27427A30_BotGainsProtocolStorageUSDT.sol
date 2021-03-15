// SPDX-License-Identifier: ISC

pragma solidity ^0.5.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract BotGainsProtocolStorageUSDT is Ownable{
    using SafeMath for uint256;
    
    //addressstate variable
    address payable botWallet;
    address payable adminFeeWallet;
    address payable managementFeeWallet;
    address payable divsFeeWallet;
    address payable bonusWallet;
    
    uint256 public minUSDT = 1e18; // 1 USDT
    uint256 public maxUSDT = 1e22; //10,000 USDT
    uint256 public maxPoolSize = 5e26;
    uint256 public cycleLength;
    
    uint256 private lockTimer;
    uint256 private unlockTimer;
    
    constructor (address payable _tradingWallet,address payable _adminFeeWallet,address payable _managementFeeWallet,address payable _divsFeeWallet, address payable _bonusWallet) public {
        //assign wallet addresses
        botWallet = _tradingWallet;
        adminFeeWallet = _adminFeeWallet;
        managementFeeWallet = _managementFeeWallet;
        divsFeeWallet = _divsFeeWallet;
        bonusWallet = _bonusWallet;
        
        cycleLength = 30;
        
        unlockTimer= 30 minutes;
        lockTimer= 30 minutes;
    }
    
    
    function changeCycleLength(uint256 _days) onlyOwner external {
        require(_days > 1, "must be greater than a single day");
        cycleLength = _days;
    }
    function _cycleLength() public view returns(uint256) {
        return cycleLength;
    }
    

    function changeLockTimer(uint256 _minutes) onlyOwner external {
        lockTimer = _minutes.mul(1 minutes);
    }
    function changeUnlockTimer(uint256 _minutes) onlyOwner external {
        unlockTimer = _minutes.mul(1 minutes);
    }
    function _lockTimer() public view returns(uint256){
        return lockTimer;
    }
    function _unlockTimer() public view returns(uint256){
        return unlockTimer;
    }
    
    function changeMinUSDT(uint256 amount) onlyOwner external {
        minUSDT = amount;
    }
    function changeMaxUSDT(uint256 amount) onlyOwner external {
        maxUSDT = amount;
    }
    function changeMaxPoolSize(uint256 amount) onlyOwner external {
        maxPoolSize = amount;
    }
    function _minUSDT() public view returns(uint256){
        return minUSDT;
    }
    function _maxUSDT() public view returns(uint256){
        return maxUSDT;
    }
    function _maxPoolSize() public view returns(uint256){
        return maxPoolSize;
    }
    
    
    
    
    
    
    function changeAdminFeeWallet(address payable _admin) onlyOwner external{
        adminFeeWallet = _admin;
    }
    function changeManagementFeeWallet(address payable _manage) onlyOwner external{
        managementFeeWallet = _manage;
    }
    function changeDivsFeeWallet(address payable _divs) onlyOwner external{
        divsFeeWallet = _divs;
    }
    function changeBonusWallet(address payable _bonus) onlyOwner external{
        bonusWallet = _bonus;
    }
    function changeTradingWallet(address payable _tradingWallet) onlyOwner external{
        botWallet = _tradingWallet;
    }
    
    
    function _tradingWallet() public view returns(address payable){
        return botWallet;
    }
    function _adminFeeWallet() public view returns(address payable){
        return adminFeeWallet;
    }
    function _managementFeeWallet() public view returns(address payable){
        return managementFeeWallet;
    }
    function _divsFeeWallet() public view returns(address payable){
        return divsFeeWallet;
    }
    function _bonusWallet() public view returns(address payable){
        return bonusWallet;
    }
}