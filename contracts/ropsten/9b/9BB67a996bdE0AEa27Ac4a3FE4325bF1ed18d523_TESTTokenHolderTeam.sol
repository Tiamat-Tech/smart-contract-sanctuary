// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @dev Contract module which provides several vesting algorithms.
 * there is an account (an owner) that is granted exclusive access to
 * send function.
 *
 * There is no hardcoded total supply variable (rely on balanceOf instead).
 * There is no hardcoded destination addresses (rely on addresses provided by send function)
 *
 * This module is used through inheritance.
 */
abstract contract TESTTokenHolder is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    string public name;
    uint256 public createdAt;//counter start

    //by default first portion of tokens available right after contract deployment
    //this can be changed by increasing "fullLockMonths" variable
    //it means how many month should pass before first portion of tokens can be claimed
    uint256 public fullLockMonths;

    //# of releases, months
    uint256 public unlockRate;

    //How many tokens can be unlocked every month
    //this variable is used for linear releases
    //in case non-linear the perMonth variable should be = 0
    uint256 public perMonth;

    //How many tokens should be unlocked in case non-linear release 
    //example: perMonthCustom = [1024, 0, 2048] means that
    // month #1 - 1024 tokens; month #2 - no tokens at all;   month #3 - 2048 tokens;
    uint256[] public perMonthCustom;

    uint256 public sent;
    address public testTokenAddress;

    constructor (address _testTokenAddress) {
        testTokenAddress = _testTokenAddress;
        createdAt = block.timestamp;
    }

    /**
    @notice This function is used to return amout of available tokens
    @return amount of tokens that can be sent instantly by "send" function 
    */
   function getAvailableTokens() public view  returns (uint256) {

        //2592000 = 1 month;
        //months variable starts from 0; 
        uint256 months = block.timestamp.sub(createdAt).div(2592000);

        if(months >= fullLockMonths+unlockRate){//lock is over, we can unlock everything we have
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

    /**
    @notice This function is used to send unlocked tokens
    @param to is a distination address
    @param amount how many tokens to sent
    */
    function send(address to, uint256 amount) onlyOwner nonReentrant external {
        require(getAvailableTokens() >= amount, "available amount is less than requested amount");
        sent = sent.add(amount);
        IERC20(testTokenAddress).transfer(to, amount);
    }

}