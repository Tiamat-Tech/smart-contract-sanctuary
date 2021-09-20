// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";
/// @author PlanetSandbox Blockchain Dev
contract PlanetSandboxToken is ERC20, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    uint256 public constant DECIMAL_MULTIPLIER = 10**18;
    uint256 public constant TOTAL_SUPPLY = (10**8) * DECIMAL_MULTIPLIER;
    uint256 public constant INITIAL_SUPPLY = 38 * (10**5) * DECIMAL_MULTIPLIER;

    uint256 public startTimeVesting; // time vesting

    mapping(address => VestingInfo) private _vestingList;

    struct VestingInfo {
        bool isActive;
        uint256 amount; // total amount
        uint256 startTimeVesting; // time start vesting
        uint256 startTimeCliff; // time start cliff
        uint256 claimedAmount; // claimed vest
        uint256 cliff; // time cliff before vesting
        uint256 releaseTotalRounds;
        uint256 daysPerRound;
        uint256 tgePercent;
        uint256 releaseTgeRounds;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev Set first day token listing on exchange for vesting process
     */
    function setTokenVestingTime(uint256 _vestingTime) public onlyOwner {
        require(
            _vestingTime >= block.timestamp,
            "PlanetSandbox: Token listing must be in future date"
        );

        startTimeVesting = _vestingTime;
    }

    function addVestingToken(
        address beneficiary,
        uint256 amount,
        uint256 cliff,
        uint256 releaseTotalRounds,
        uint256 daysPerRound,
        uint256 tgePercent,
        uint256 releaseTgeRounds
    ) external onlyOwner {
        require(beneficiary != address(0), "PlanetSandbox: Zero address");
        require(startTimeVesting > 0, "PlanetSandbox: No vesting time");
        require(
            !_vestingList[beneficiary].isActive,
            "PlanetSandbox: Duplicate vesting address"
        );
        VestingInfo memory info = VestingInfo(
            true,
            amount,
            startTimeVesting,
            startTimeVesting.add(30 days),
            0,
            cliff,
            releaseTotalRounds,
            daysPerRound,
            tgePercent,
            releaseTgeRounds
        );
        _vestingList[beneficiary] = info;
    }

    function revokeVestingToken(address user) external onlyOwner {
        require(
            _vestingList[user].isActive,
            "PlanetSandbox: Invalid beneficiary"
        );
        uint256 claimableAmount = _getVestingClaimableAmount(user);
        require(
            totalSupply().add(claimableAmount) <= TOTAL_SUPPLY,
            "PlanetSandbox: Max supply exceeded"
        );
        _vestingList[user].isActive = false;
        _mint(user, claimableAmount);
    }

    function getVestingInfoByUser(address user)
        external
        view
        returns (VestingInfo memory)
    {
        return _vestingList[user];
    }

    /**
     * @dev
     *
     * Requirements:
     *
     * - `user` cannot be the zero address.
     */
    function _getVestingClaimableAmount(address user)
        internal
        view
        returns (uint256 claimableAmount)
    {
        if (!_vestingList[user].isActive) return 0;
        VestingInfo memory info = _vestingList[user];
        if (block.timestamp < info.startTimeVesting) return 0;

        claimableAmount = 0;
        uint256 tgeReleasedAmount = 0;
        uint256 roundReleasedAmount = 0;
        uint256 releasedAmount = 0;
        uint256 releaseTime = info.startTimeCliff.add(info.cliff.mul(1 days));
        uint256 tgeRounds = (
            (block.timestamp.sub(info.startTimeVesting)).div(30 days)
        ).add(1);

        if (info.tgePercent > 0) {
            if (tgeRounds <= info.releaseTgeRounds) {
                tgeReleasedAmount = info
                    .amount
                    .mul(info.tgePercent)
                    .div(100)
                    .mul(tgeRounds)
                    .div(info.releaseTgeRounds);
            } else {
                tgeReleasedAmount = info.amount.mul(info.tgePercent).div(100);
            }
        }

        if (block.timestamp >= releaseTime) {
            uint256 roundsPassed = (
                (block.timestamp.sub(releaseTime)).div(
                    info.daysPerRound.mul(1 days)
                )
            ).add(1);

            if (roundsPassed >= info.releaseTotalRounds) {
                roundReleasedAmount = info.amount.sub(tgeReleasedAmount);
            } else {
                roundReleasedAmount = info
                    .amount
                    .sub(tgeReleasedAmount)
                    .mul(roundsPassed)
                    .div(info.releaseTotalRounds);
            }
        }

        releasedAmount = tgeReleasedAmount.add(roundReleasedAmount);

        if (releasedAmount > info.claimedAmount) {
            claimableAmount = releasedAmount.sub(info.claimedAmount);
        }
    }

    function getVestingClaimableAmount(address user)
        external
        view
        returns (uint256)
    {
        return _getVestingClaimableAmount(user);
    }

    function claimVestingToken() external nonReentrant returns (uint256) {
        require(
            _vestingList[_msgSender()].isActive,
            "PlanetSandbox: Not in vesting list"
        );
        uint256 claimableAmount = _getVestingClaimableAmount(_msgSender());
        require(claimableAmount > 0, "PlanetSandbox: Nothing to claim");
        require(
            (totalSupply().add(claimableAmount)) <= TOTAL_SUPPLY,
            "PlanetSandbox: Max supply exceeded"
        );
        _vestingList[_msgSender()].claimedAmount = _vestingList[_msgSender()]
            .claimedAmount
            .add(claimableAmount);
        _mint(_msgSender(), claimableAmount);
    }

    function withdrawERC20(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "PlanetSandbox: Amount must be greater than 0");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "PlanetSandbox: ERC20 not enough balance"
        );
        require(
            IERC20(token).transfer(_msgSender(), amount),
            "PlanetSandbox: transfer ERC20 failed"
        );
    }

    receive() external payable {
        revert();
    }

    function test(address user, uint256 timestamp)
        external
        view
        returns (uint256 claimableAmount)
    {
        return _test(user, timestamp);
    }

    function _test(address user, uint256 timestamp)
        internal
        view
        returns (uint256 claimableAmount)
    {
        if (!_vestingList[user].isActive) return 0;
        VestingInfo memory info = _vestingList[user];

        claimableAmount = 0;
        uint256 tgeReleasedAmount = 0;
        uint256 roundReleasedAmount = 0;
        uint256 releasedAmount = 0;
        uint256 releaseTime = info.startTimeCliff.add(info.cliff.mul(1 days));
        uint256 tgeRounds = (
            (timestamp.sub(info.startTimeVesting)).div(30 days)
        ).add(1);

        if (info.tgePercent > 0) {
            if (tgeRounds <= info.releaseTgeRounds) {
                tgeReleasedAmount = info
                    .amount
                    .mul(info.tgePercent)
                    .div(100)
                    .mul(tgeRounds)
                    .div(info.releaseTgeRounds);
            } else {
                tgeReleasedAmount = info.amount.mul(info.tgePercent).div(100);
            }
        }

        if (timestamp >= releaseTime) {
            uint256 roundsPassed = (
                (timestamp.sub(releaseTime)).div(info.daysPerRound.mul(1 days))
            ).add(1);

            if (roundsPassed >= info.releaseTotalRounds) {
                roundReleasedAmount = info.amount.sub(tgeReleasedAmount);
            } else {
                roundReleasedAmount = info
                    .amount
                    .sub(tgeReleasedAmount)
                    .mul(roundsPassed)
                    .div(info.releaseTotalRounds);
            }
        }

        releasedAmount = tgeReleasedAmount.add(roundReleasedAmount);

        if (releasedAmount > info.claimedAmount) {
            claimableAmount = releasedAmount.sub(info.claimedAmount);
        }
    }

    // function tttttttt(uint256 timestamp) external view returns (VestingInfo memory) {
    //     return _adddd(_msgSender(),timestamp);
    // }

    // function _adddd(address user,uint256 timestamp) internal view returns (VestingInfo memory) {
    //     return _vestingList[user];
    // }

    function testClaim(uint256 timestamp) external nonReentrant returns (uint256) {
        require(
            _vestingList[msg.sender].isActive,
            "PlanetSandbox: Not in vesting list"
        );
        
        uint256 claimableAmount = _test(msg.sender, timestamp);
        require(claimableAmount > 0, "PlanetSandbox: Nothing to claim");
        require(
            (totalSupply().add(claimableAmount)) <= TOTAL_SUPPLY,
            "PlanetSandbox: Max supply exceeded"
        );
        _vestingList[msg.sender].claimedAmount = _vestingList[msg.sender]
            .claimedAmount
            .add(claimableAmount);
        _mint(msg.sender, claimableAmount);
    }
}