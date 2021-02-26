// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

abstract contract TESTTokenHolder is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    string public name;
    uint256 public createdAt;

    uint256 public fullLockMonths;
    uint256 public unlockRate;
    uint256 public perMonth;
    uint256[] public perMonthCustom;
    uint256 public sent;

    address public testTokenAddress;

    constructor (address _testTokenAddress) {
        testTokenAddress = _testTokenAddress;
        createdAt = block.timestamp;
    }

   function getAvailableTokens() public view  returns (uint256) {

        uint256 months = block.timestamp.sub(createdAt).div(2592000);//starts from 0

        if(months >= fullLockMonths+unlockRate){//lock is over
            return IERC20(testTokenAddress).balanceOf(address(this));
        }else if(months < fullLockMonths){
            //too early, tokens are still under full lock;
            return 0;
        }

        //+1 due to beginning of a month
        uint256 potentialAmount;
        if(perMonthCustom.length > 0){
            for (uint256 i=0; i<months+1; i++) {
                potentialAmount += perMonthCustom[i];
            }
        }else{
           potentialAmount = (months-fullLockMonths+1).mul(perMonth);
        }

        return potentialAmount.sub(sent);
    }

    function send(address to, uint256 amount) onlyOwner nonReentrant external {
        require(getAvailableTokens() >= amount, "available amount is less than requested amount");
        sent = sent.add(amount);
        IERC20(testTokenAddress).transfer(to, amount);
    }

}