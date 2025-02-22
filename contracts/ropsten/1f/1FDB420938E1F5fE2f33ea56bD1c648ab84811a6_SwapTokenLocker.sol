// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./SwapAdmin.sol";

contract SwapTokenLocker is SwapAdmin {
    using SafeMath for uint;

    struct LockInfo {
        uint256 amount;
        uint256 lockTimestamp; // lock time at block.timestamp
        uint256 lockHours;
        uint256 claimedAmount;
        uint256 lastUpdated;
    }
    address immutable token;
    mapping (address => LockInfo) public lockData;
    
    constructor(address _admin, address _token) public SwapAdmin(_admin) {
        token = _token;
    }
    
    function emergencyWithdraw() external onlyAdmin {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function getToken() external view returns(address) {
        return token;
    }
    
	function getLockData(address _user) external view returns(uint256, uint256, uint256, uint256, uint256) {
        require(_user != address(0), "User address is invalid");

        LockInfo storage _lockInfo = lockData[_user];
		return (_lockInfo.amount, _lockInfo.lockTimestamp, _lockInfo.lockHours, _lockInfo.claimedAmount, _lockInfo.lastUpdated);
	}

    function sendLockTokenMany(
        address[] calldata _users, 
        uint256[] calldata _amounts, 
        //uint256[] calldata _lockTimestamps, 
        uint256[] calldata _lockHours,
        uint256 _sendAmount
    ) external onlyAdmin {
        require(_users.length == _amounts.length, "array length not eq");
        require(_users.length == _lockHours.length, "array length not eq");
        //require(_users.length == _lockTimestamps.length, "array length not eq");
        require(_sendAmount >0 , "Amount is invalid");

        IERC20(token).transferFrom(msg.sender, address(this), _sendAmount);
        
        for (uint256 j = 0; j < _users.length; j++) {
            sendLockToken(_users[j], _amounts[j], /*_lockTimestamps[j],*/ _lockHours[j]);
        }        
    }

    function sendLockToken(
        address _user, 
        uint256 _amount, 
        //uint256 _lockTimestamp, 
        uint256 _lockHours
    ) internal {
        require(_amount > 0, "amount can not zero");
        require(_lockHours > 0, "lock hours need more than zero");
        //require(_lockTimestamp > 0, "lock timestamp need more than zero");
        require(lockData[_user].amount == 0, "this address has already locked");
        
        LockInfo memory lockinfo = LockInfo({
            amount: _amount,
            lockTimestamp: block.timestamp, //_lockTimestamp,
            lockHours: _lockHours,
            lastUpdated: block.timestamp,
            claimedAmount: 0
        });

        lockData[_user] = lockinfo;
    }
    
    function claimToken(uint256 _amount) external returns (uint256) {
        require(_amount > 0, "Invalid parameter amount");
        address _user = msg.sender;

        LockInfo storage _lockInfo = lockData[_user];

        require(_lockInfo.lockTimestamp <= block.timestamp, "Vesting time is not started");
        require(_lockInfo.amount > 0, "No lock token to claim");

        uint256 passhours = block.timestamp.sub(_lockInfo.lockTimestamp).div(1 hours);
        require(passhours > 0, "need wait for one hour at least");
        require((block.timestamp - _lockInfo.lastUpdated) > 1 hours, "You have to wait at least an hour to claim");

        uint256 available = 0;
        if (passhours >= _lockInfo.lockHours) {
            available = _lockInfo.amount;
        } else {
            available = _lockInfo.amount.div(_lockInfo.lockHours).mul(passhours);
        }
        available = available.sub(_lockInfo.claimedAmount);
        require(available > 0, "not available claim");
        uint256 claim = _amount;
        if (_amount > available) { // claim as much as possible
            claim = available;
        }

        _lockInfo.claimedAmount = _lockInfo.claimedAmount.add(claim);

        IERC20(token).transfer(_user, claim);
        _lockInfo.lastUpdated = block.timestamp;

        return claim;
    }
}