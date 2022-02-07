pragma solidity ^0.8.4;
pragma abicoder v2;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/AccessProtected.sol";
import "./utils/BlackList.sol";

contract NumbersVesting is AccessProtected, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;
    address public tokenAddress;
    BlackList public blacklist;

    struct Claim {
        bool isActive;
        uint256 vestAmount;
        uint256 unlockAmount;
        uint256 unlockTime;
        uint256 startTime;
        uint256 endTime;
        uint256 amountClaimed;
    }

    mapping(address => Claim) private claims;

    event ClaimCreated(
        address _creator,
        address _beneficiary,
        uint256 _vestAmount,
        uint256 _unlockAmount,
        uint256 _unlockTime,
        uint256 _startTime,
        uint256 _endTime
    );
    event Claimed(address _beneficiary, uint256 _amount);
    event Revoked(address _beneficiary);

    constructor(address _tokenAddress, address _blacklistAddress) {
        require(_tokenAddress.isContract(), "_tokenAddress must be a contract");
        require(_blacklistAddress.isContract(), "_tokenAddress must be a contract");
        tokenAddress = _tokenAddress;
        blacklist = BlackList(_blacklistAddress);
    }

    function createClaim(
        address _beneficiary,
        uint256 _vestAmount,
        uint256 _unlockAmount,
        uint256 _unlockTime,
        uint64 _startTime,
        uint64 _endTime
    ) public onlyAdmin {
        require(!claims[_beneficiary].isActive, "CLAIM_ACTIVE");
        require(_endTime > _startTime, "INVALID_TIME");
        require(_endTime != 0, "INVALID_TIME");
        require(_startTime > _unlockTime, "INVALID_TIME");
        require(_beneficiary != address(0), "INVALID_ADDRESS");
        require(_vestAmount > 0, "INVALID_AMOUNT");
        require(
            ERC20(tokenAddress).allowance(msg.sender, address(this)) >= (_vestAmount.add(_unlockAmount)),
            "INVALID_ALLOWANCE"
        );
        ERC20(tokenAddress).transferFrom(msg.sender, address(this), _vestAmount.add(_unlockAmount));
        Claim memory newClaim = Claim({
            isActive: true,
            vestAmount: _vestAmount,
            unlockAmount: _unlockAmount,
            unlockTime: _unlockTime,
            startTime: _startTime,
            endTime: _endTime,
            amountClaimed: 0
        });
        claims[_beneficiary] = newClaim;
        emit ClaimCreated(msg.sender, _beneficiary, _vestAmount, _unlockAmount, _unlockTime, _startTime, _endTime);
    }

    function createBatchClaim(
        address[] memory _beneficiaries,
        uint256[] memory _vestAmounts,
        uint256[] memory _unlockAmounts,
        uint256[] memory _unlockTimes,
        uint64[] memory _startTimes,
        uint64[] memory _endTimes
    ) external onlyAdmin {
        uint256 length = _beneficiaries.length;
        require(
            _vestAmounts.length == length &&
                _unlockAmounts.length == length &&
                _unlockTimes.length == length &&
                _startTimes.length == length &&
                _endTimes.length == length,
            "LENGTH_MISMATCH"
        );
        for (uint256 i; i < length; i++) {
            createClaim(
                _beneficiaries[i],
                _vestAmounts[i],
                _unlockAmounts[i],
                _unlockTimes[i],
                _startTimes[i],
                _endTimes[i]
            );
        }
    }

    function getClaim(address beneficiary) external view returns (Claim memory) {
        require(beneficiary != address(0), "INVALID_ADDRESS");
        return (claims[beneficiary]);
    }

    function claimableAmount(address beneficiary) public view returns (uint256) {
        Claim memory _claim = claims[beneficiary];
        if (block.timestamp < _claim.startTime && block.timestamp < _claim.unlockTime) return 0;
        if (_claim.amountClaimed == _claim.vestAmount) return 0;
        uint256 currentTimestamp = block.timestamp > _claim.endTime ? _claim.endTime : block.timestamp;
        uint256 claimPercent;
        uint256 claimAmount;
        uint256 unclaimedAmount;
        if (_claim.unlockTime <= block.timestamp && _claim.startTime <= block.timestamp) {
            claimPercent = currentTimestamp.sub(_claim.startTime).mul(1e18).div(_claim.endTime.sub(_claim.startTime));
            claimAmount = _claim.vestAmount.mul(claimPercent).div(1e18).add(_claim.unlockAmount);
            unclaimedAmount = claimAmount.sub(_claim.amountClaimed);
        } else if (_claim.unlockTime > block.timestamp && _claim.startTime <= block.timestamp) {
            claimPercent = currentTimestamp.sub(_claim.startTime).mul(1e18).div(_claim.endTime.sub(_claim.startTime));
            claimAmount = _claim.vestAmount.mul(claimPercent).div(1e18);
            unclaimedAmount = claimAmount.sub(_claim.amountClaimed);
        } else {
            claimAmount = _claim.unlockAmount;
            unclaimedAmount = claimAmount.sub(_claim.amountClaimed);
        }
        return unclaimedAmount;
    }

    function claim() external nonReentrant {
        require(!blacklist.checkBlackList(msg.sender), "You are a blacklisted Member");
        address beneficiary = msg.sender;
        Claim memory _claim = claims[beneficiary];
        require(_claim.isActive, "CLAIM_INACTIVE");
        uint256 unclaimedAmount = claimableAmount(beneficiary);
        ERC20(tokenAddress).transfer(beneficiary, unclaimedAmount);
        _claim.amountClaimed = _claim.amountClaimed.add(unclaimedAmount);
        if (_claim.amountClaimed == _claim.vestAmount) _claim.isActive = false;
        claims[beneficiary] = _claim;
        emit Claimed(beneficiary, unclaimedAmount);
    }

    function withdrawTokens(address wallet) external onlyOwner nonReentrant {
        uint256 balance = ERC20(tokenAddress).balanceOf(address(this));
        require(balance > 0, "Nothing to withdraw");
        ERC20(tokenAddress).transfer(wallet, balance);
    }

    function revoke(address beneficiary) external onlyAdmin {
        require(claims[beneficiary].isActive != false, "Already invalidated");
        claims[beneficiary].isActive = false;
        emit Revoked(beneficiary);
    }
}