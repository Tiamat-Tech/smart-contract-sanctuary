// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../claim/RunnerClaim.sol";

interface IStakeSum {
    function minTimeToStake() external view returns (uint256);

    function balanceOf(address user) external view returns (uint256);
}

// solhint-disable not-rely-on-time
contract RunnerIdo is RunnerClaim {
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

    address[2] public stakingContracts = [
        0x2768f5d352f7aC67218027A1A7EAA8977c40d006,
        0xD05198fEFD618030d1E2325D4f01Eb5908A4be20
    ];

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
    ) RunnerClaim(_rewardToken) {
        require(_startTime < _endTime, "Invalid start timestamp");
        require(_endTime > block.timestamp, "Ivvalid finish timestamp");

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

    modifier onlyWhitelisted(address _address) {
        require(whitelisted(_address), "Not whitelisted");
        _;
    }

    function whitelisted(address _address) public view returns (bool) {
        uint256 staked;

        for (uint256 i = 0; i < stakingContracts.length; i++) {
            staked += IStakeSum(stakingContracts[i]).balanceOf(_address);
        }

        return staked >= 1000 * 1e18;
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