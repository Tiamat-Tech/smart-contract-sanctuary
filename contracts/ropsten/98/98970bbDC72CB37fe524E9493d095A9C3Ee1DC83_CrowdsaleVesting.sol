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
    mapping(address => bool) private blacklist;

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

    constructor(
        address _ddao,
        address _addao,
        uint256 _startDate
    ) {
        require(
            block.timestamp < _startDate,
            "startDate must be in the future"
        );
        ddao = IERC20(_ddao);
        addao = IERC20(_addao);
        startDate = _startDate;
    }

    function claim(uint256 _round) public {
        uint256 tokensToSend = availableToClaim(msg.sender, _round);
        require(tokensToSend > 0, "Nothing to claim");

        tokensClaimed[msg.sender][_round] += tokensToSend;

        addao.safeTransferFrom(msg.sender, address(this), tokensToSend);

        ddao.safeTransfer(msg.sender, tokensToSend);
    }

    function availableToClaim(address _address, uint256 _round)
        public
        view
        returns (uint256)
    {
        if (calculateUnlockedTokens(_address, _round, 0) > 0) {
            return
                calculateUnlockedTokens(_address, _round, 0) -
                tokensClaimed[_address][_round];
        }
        return 0;
    }

    function calculateUnlockedTokens(
        address _address,
        uint256 _round,
        uint256 _date
    ) public view returns (uint256) {
        require(
            _round == roundSeed ||
                _round == roundPrivate1 ||
                _round == roundPrivate2,
            "CrowdsaleVesting: this round has not supported"
        );
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

        // Inner information by wallet address
        uint256 availableAmount;

        if (_round == roundSeed) {
            availableAmount = seed[_address];

            uint256 secondsPassed = timestamp - (startDate + lockupPeriod);
            secondsPassed = secondsPassed > vestingPeriodSeed * oneMonth
                ? vestingPeriodSeed
                : secondsPassed;

            result +=
                (availableAmount * secondsPassed) /
                (vestingPeriodSeed * oneMonth);
        }
        if (_round == roundPrivate1) {
            availableAmount = private1[_address];

            uint256 secondsPassed = timestamp - (startDate + lockupPeriod);
            secondsPassed = secondsPassed > vestingPeriodPrivate1 * oneMonth
                ? vestingPeriodPrivate1
                : secondsPassed;

            result +=
                (availableAmount * secondsPassed) /
                (vestingPeriodPrivate1 * oneMonth);
        }
        if (_round == roundPrivate2) {
            availableAmount = private2[_address];

            uint256 secondsPassed = timestamp - (startDate + lockupPeriod);
            secondsPassed = secondsPassed > vestingPeriodPrivate2 * oneMonth
                ? vestingPeriodPrivate2
                : secondsPassed;

            result +=
                (availableAmount * secondsPassed) /
                (vestingPeriodPrivate2 * oneMonth);
        }

        return result;
    }

    function claimTokens(address _ddao) public onlyOwner {
        IERC20(_ddao).safeTransfer(
            msg.sender,
            IERC20(_ddao).balanceOf(address(this))
        );
    }

    function lockAddress(address _address) public onlyOwner {
        blacklist[_address] = true;
    }

    function unlockAddress(address _address) public onlyOwner {
        blacklist[_address] = false;
    }

    function adminGetCoin(uint256 amount) public onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    function adminGetToken(address tokenAddress, uint256 amount)
        public
        onlyOwner
    {
        IERC20 ierc20Token = IERC20(tokenAddress);
        ierc20Token.safeTransfer(msg.sender, amount);
    }
}