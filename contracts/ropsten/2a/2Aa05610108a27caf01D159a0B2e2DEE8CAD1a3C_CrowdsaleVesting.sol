// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import "./token/ERC20/IERC20.sol";
import "./token/ERC20/SafeERC20.sol";
import "./utils/Ownable.sol";
import "./Participants.sol";

import "hardhat/console.sol";

/**
 * @notice Allows each token to be associated with a creator.
 */
contract CrowdsaleVesting is Ownable, Participants {
    using SafeERC20 for IERC20;
    IERC20 public ddao;
    IERC20 public addao;

    mapping(address => mapping(uint256 => uint256)) public tokensClaimed;
    mapping(address => bool) public blacklist;

    uint256 public roundSeed = 0;
    uint256 public roundPrivate1 = 1;
    uint256 public roundPrivate2 = 2;

    uint256 public startDate;
    uint256 public lockupPeriod = 0;
    // Vesting periods are set in months
    uint256 public vestingPeriodSeed = 24;
    uint256 public vestingPeriodPrivate1 = 18;
    uint256 public vestingPeriodPrivate2 = 12;

    uint256 public oneMonth = 30 days;

    struct ClaimedInfo {
        uint256 timestamp;
        uint256 amount;
        uint256 number;
        bytes32 txHash;
    }
    mapping(uint8 => mapping(address => uint256)) public claimAddressNumber;
    mapping(uint8 => mapping(address => mapping(uint256 => ClaimedInfo))) public claimByAddress; // Should know about round

    constructor(
        address _ddao,
        address _addao,
        uint256 _startDate
    ) {
        ddao = IERC20(_ddao);
        addao = IERC20(_addao);
        startDate = _startDate;
    }

    function claim(uint8 _round) public {
        uint256 tokensToSend = balanceOf(msg.sender, _round);
        require(tokensToSend > 0, "CrowdsaleVesting: Nothing to claim");

        require(!blacklist[msg.sender], "CrowdsaleVesting: This wallet address has been blocked");

        tokensClaimed[msg.sender][_round] += tokensToSend;

        addao.safeTransferFrom(msg.sender, address(this), tokensToSend);

        ddao.safeTransfer(msg.sender, tokensToSend);

        uint256 nextNumber = claimAddressNumber[_round][msg.sender] + 1;
        bytes32 txHash = blockhash(block.number);
        claimByAddress[_round][msg.sender][nextNumber] = ClaimedInfo(block.timestamp, tokensToSend, nextNumber, txHash);
    }

    function balanceOf(address _address, uint8 _round) public view returns (uint256) {
        if (calculateUnlockedTokens(_address, _round, 0) > 0) {
            return calculateUnlockedTokens(_address, _round, 0) - tokensClaimed[_address][_round];
        }
        return 0;
    }

    function calculateUnlockedTokens(
        address _address,
        uint8 _round,
        uint256 _date
    ) public view returns (uint256) {
        require(_round == roundSeed || _round == roundPrivate1 || _round == roundPrivate2, "CrowdsaleVesting: This round has not supported");
        uint256 result;

        uint256 timestamp;
        if (_date != 0) {
            timestamp = _date;
        } else {
            timestamp = block.timestamp;
        }

        if (timestamp <= startDate + lockupPeriod) {
            return result;
        }

        uint256 vestedAmount = addao.balanceOf(_address);
        if (vestedAmount == 0) {
            return result;
        }

        if (_round == roundSeed) {
            result += availableTokenByRound(seed[_address], vestingPeriodSeed, timestamp);
        }
        if (_round == roundPrivate1) {
            result += availableTokenByRound(private1[_address], vestingPeriodPrivate1, timestamp);
        }
        if (_round == roundPrivate2) {
            result += availableTokenByRound(private2[_address], vestingPeriodPrivate2, timestamp);
        }

        return result;
    }

    function availableTokenByRound(
        uint256 _availableAmount,
        uint256 _vestingPeriod,
        uint256 _timestamp
    ) internal view returns (uint256) {
        uint256 secondsPassed = _timestamp - (startDate + lockupPeriod);
        secondsPassed = secondsPassed > _vestingPeriod * oneMonth ? (_vestingPeriod * oneMonth) : secondsPassed;

        return (_availableAmount * secondsPassed) / (_vestingPeriod * oneMonth);
    }

    function lockAddress(address _address) public onlyOwner {
        blacklist[_address] = true;
    }

    function unlockAddress(address _address) public onlyOwner {
        blacklist[_address] = false;
    }

    function adminGetCoin(uint256 _amount) public onlyOwner {
        payable(msg.sender).transfer(_amount);
    }

    function adminGetToken(address _tokenAddress, uint256 _amount) public onlyOwner {
        IERC20(_tokenAddress).safeTransfer(msg.sender, _amount);
    }
}