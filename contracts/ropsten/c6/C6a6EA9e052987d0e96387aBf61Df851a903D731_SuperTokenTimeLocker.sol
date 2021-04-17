// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SuperTokenTimeLocker {
    using SafeERC20 for IERC20;


    mapping(address => uint256) private beneficiaries;

    mapping(address => uint256) private releaseTimes;

    IERC20 immutable private _token;

    function clearBeneficiary(address beneficiary, uint256 tokenAmount) private {
        beneficiaries[beneficiary] -= tokenAmount;
        releaseTimes[beneficiary] = 0;
    }

    function setBeneficiary(address beneficiary, uint256 tokenAmount, uint256 releaseTime) private {
        beneficiaries[beneficiary] += tokenAmount;
        releaseTimes[beneficiary] = releaseTime;
    }
    
    function getReleaseTime(address beneficiary) private view returns (uint256) {
        return releaseTimes[beneficiary];
    }
    
    function getReleaseAmount(address beneficiary) private view returns (uint256) {
        return beneficiaries[beneficiary];
    }

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20) {
        return _token;
    }

    constructor (IERC20 token_) {
        // solhint-disable-next-line not-rely-on-time
        //        require(releaseTime_ > block.timestamp, "TokenTimelock: release time is before current time");
        _token = token_;
        //        _beneficiary = beneficiary_;
        //        _releaseTime = releaseTime_;
    }


    function lock(uint256 amountToLock, uint256 amountReleaseTime) payable public virtual {
        uint256 amount = token().balanceOf(address(msg.sender));
        require(amountToLock > 0, "You need to lock some token");
        require(amountToLock <= amount, "Not enough tokens to be locked");
        require(block.timestamp > amountReleaseTime, "TokenTimelock: current time is after release time");
        require(amountReleaseTime > 0, "You need to lock some token with a vail time");
        require(getReleaseTime(address(msg.sender)) < amountReleaseTime, "You need set a new release time after old");
        setBeneficiary(address(msg.sender), amountToLock, amountReleaseTime);
        // Before this action you must approve this contract.
        // token().safeTransferFrom(address(msg.sender), address(this), amountToLock);
        token().transferFrom(address(msg.sender), address(this), amountToLock);
    }
    
    function approve(uint256 value) public virtual {
        token().safeIncreaseAllowance(address(msg.sender), value);
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public virtual {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= getReleaseTime(address(msg.sender)), "TokenTimelock: current time is before release time");

        uint256 amount = token().balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");
        
        uint256 needReleaseAmount = getReleaseAmount(address(msg.sender));
        require(needReleaseAmount <= amount, "TokenTimelock: no tokens to release");
        require(needReleaseAmount > 0, "TokenTimelock: no tokens to release");
        
        token().safeTransfer(address(msg.sender), needReleaseAmount);
        clearBeneficiary(address(msg.sender), needReleaseAmount);
    }
}