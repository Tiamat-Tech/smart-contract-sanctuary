// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import "./token/ERC20/IERC20.sol";
import "./token/ERC20/SafeERC20.sol";
import "./utils/Ownable.sol";

import "hardhat/console.sol";

/**
 * @notice Allows each token to be associated with a creator.
 */
contract CrowdsaleVesting is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public ddao;
    IERC20 public addao;

    uint256 public roundSeed = 0;
    uint256 public roundPrivate1 = 1;
    uint256 public roundPrivate2 = 2;

    mapping(address => uint256) public vestedAmount;
    mapping(address => uint256) public tokensClaimed;
    mapping(address => bool) private blacklist;

    uint256 public startDate;
    uint256 public oneMonth = 30 days;

    uint256 public totalVested;

    uint256 public lockupPeriod = 0;
    // Vesting periods are set in months
    uint256 public vestingPeriodSeed = 24;
    uint256 public vestingPeriodPrivate1 = 18;
    uint256 public vestingPeriodPrivate2 = 12;

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

        tokensClaimed[msg.sender] += tokensToSend;

        addao.safeTransferFrom(msg.sender, address(this), tokensToSend);

        ddao.safeTransfer(msg.sender, tokensToSend);
    }

    function availableToClaim(address _address, uint256 _round)
        public
        view
        returns (uint256)
    {
        if (unlockedTokens(_address, _round) > 0) {
            return unlockedTokens(_address, _round) - tokensClaimed[_address];
        }
        return 0;
    }

    function unlockedTokens(address _address, uint256 _round)
        public
        view
        returns (uint256)
    {
        require(
            _round == roundSeed ||
                _round == roundPrivate1 ||
                _round == roundPrivate2,
            "CrowdsaleVesting: this round has not supported"
        );
        uint256 result;

        if (block.timestamp <= (startDate + lockupPeriod)) {
            return result;
        }
        if (_round == roundSeed) {
            uint256 monthsPassed = ((block.timestamp -
                (startDate + lockupPeriod)) / oneMonth) + 1;
            monthsPassed = monthsPassed > vestingPeriodSeed
                ? vestingPeriodSeed
                : monthsPassed;

            result +=
                (vestedAmount[_address] * monthsPassed) /
                vestingPeriodSeed;
        }
        if (_round == roundPrivate1) {
            uint256 monthsPassed = ((block.timestamp -
                (startDate + lockupPeriod)) / oneMonth) + 1;
            monthsPassed = monthsPassed > vestingPeriodPrivate1
                ? vestingPeriodPrivate1
                : monthsPassed;

            result +=
                (vestedAmount[_address] * monthsPassed) /
                vestingPeriodPrivate1;
        }
        if (_round == roundPrivate2) {
            uint256 monthsPassed = ((block.timestamp -
                (startDate + lockupPeriod)) / oneMonth) + 1;
            monthsPassed = monthsPassed > vestingPeriodPrivate2
                ? vestingPeriodPrivate2
                : monthsPassed;

            result +=
                (vestedAmount[_address] * monthsPassed) /
                vestingPeriodPrivate2;
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

    function adminWithdraw(IERC20 _ddao) external onlyOwner {
        if (_ddao == ddao) {
            uint256 withdrawAmount = ddao.balanceOf(address(this)) -
                totalVested;
            if (withdrawAmount > 0) {
                ddao.safeTransfer(address(msg.sender), withdrawAmount);
            }
        }
        if (_ddao == IERC20(address(0))) {
            payable(owner()).transfer(address(this).balance);
        } else {
            uint256 withdrawAmount = _ddao.balanceOf(address(this));
            if (withdrawAmount > 0) {
                _ddao.safeTransfer(address(msg.sender), withdrawAmount);
            }
        }
    }
}