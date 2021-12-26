// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../claim/VestedClaim.sol";
import "../whitelisted/Whitelisted.sol";

// solhint-disable not-rely-on-time
contract IDO is VestedClaim, Whitelisted {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    uint256 public immutable tokenPrice;

    ERC20 public immutable USDTAddress; // solhint-disable-line var-name-mixedcase
    ERC20 public immutable USDCAddress; // solhint-disable-line var-name-mixedcase

    uint256 public immutable startTime; // Only for test purposes not marked as immutable. We accept the increased gas cost
    uint256 public immutable endTime; // Only for test purposes not marked as immutable. We accept the increased gas cost
    uint256 public immutable maxReward;
    uint256 public immutable maxDistribution;
    uint256 public currentDistributed;

    address public immutable treasury;

    event Bought(
        address indexed holder,
        uint256 depositedAmount,
        uint256 rewardAmount
    );

    constructor(
        uint256 _tokenPrice,
        ERC20 _rewardToken, // Provided by VestedClaim
        ERC20 _USDTAddress, // solhint-disable-line var-name-mixedcase
        ERC20 _USDCAddress, // solhint-disable-line var-name-mixedcase
        uint256 _startTime,
        uint256 _endTime,
        uint256 _claimTime,
        uint256 _maxReward,
        uint256 _maxDistribution,
        address _treasury
    ) VestedClaim(_rewardToken) {
        require( // solhint-disable-line reason-string
            _startTime < _endTime,
            "Start timestamp must be less than finish timestamp"
        );
        require( // solhint-disable-line reason-string
            _endTime > block.timestamp,
            "Finish timestamp must be more than current block time"
        );

        tokenPrice = _tokenPrice;
        USDTAddress = ERC20(_USDTAddress);
        USDCAddress = ERC20(_USDCAddress);
        startTime = _startTime;
        endTime = _endTime;
        maxReward = _maxReward;
        maxDistribution = _maxDistribution;
        treasury = _treasury;

        // Provided by VestedClaim
        claimTime = _claimTime;
    }

    modifier checkTimespan() {
        require(block.timestamp >= startTime, "Not started");
        require(block.timestamp < endTime, "Ended");
        _;
    }

    modifier checkPaymentTokenAddress(ERC20 addr) {
        require(addr == USDTAddress || addr == USDCAddress, "Unexpected token");
        _;
    }

    // We want to leave ourselves the option change claim time
    function updateClaimTimestamp(uint256 _claimTime) external onlyOwner {
        claimTime = _claimTime;
    }

    function buy(ERC20 paymentToken, uint256 depositedAmount)
        external
        checkTimespan
        onlyWhitelisted(msg.sender)
    {
        uint256 rewardTokenAmount = getTokenAmount(
            paymentToken,
            depositedAmount
        );

        currentDistributed = currentDistributed.add(rewardTokenAmount);
        require(currentDistributed <= maxDistribution, "Overfilled");

        paymentToken.safeTransferFrom(msg.sender, treasury, depositedAmount);

        UserInfo storage user = userInfo[msg.sender];
        uint256 totalReward = user.reward.add(rewardTokenAmount);
        require(totalReward <= maxReward, "More then max amount");
        addUserReward(msg.sender, rewardTokenAmount);

        emit Bought(msg.sender, depositedAmount, rewardTokenAmount);
    }

    function getTokenAmount(ERC20 paymentToken, uint256 depositedAmount)
        public
        view
        checkPaymentTokenAddress(paymentToken)
        returns (uint256)
    {
        // Reward token has 18 decimals
        return depositedAmount.mul(10**18).div(tokenPrice);
    }

    function withdrawUnallocatedToken() external onlyOwner {
        require(block.timestamp > endTime, "Sale not ended");
        uint256 amount = maxDistribution.sub(currentDistributed);

        rewardToken.safeTransfer(msg.sender, amount);
    }
}
// solhint-enable not-rely-on-time