//"SPDX-License-Identifier: MIT"
pragma solidity 0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestingReserve is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public startTime;
    uint256 public lastClaimTime;
    uint256 private constant CLAIM_DELAY = 30 days;
    uint256 private constant RELEASEAMOUNT = 245008 ether;
    uint256 private immutable END_DAY;
    uint256 public epoch;
    address private beneficiary = 0x6E600F4AF997DB70Fa84749BEEbCD3258051f5C0; //foundation multisig to claim tokens
    IERC20 private immutable KeytangoToken;
    event Claimed(uint256 amount, uint256 epoch);

    constructor(address _KeytangoTokenAddress, uint256 _startTime) public {
        KeytangoToken = IERC20(_KeytangoTokenAddress);
        startTime = _startTime;
        END_DAY = _startTime.add(2490 days); //83 months, 1 month == 30 days, 1st batch is directly minted
    }

    function getCurrentEpoch() public view returns (uint256) {
        uint256 currentEpoch = block.timestamp.sub(startTime).div(CLAIM_DELAY); // get current epoch
        return currentEpoch;
    }

    function claimTokens() external {
        require(block.timestamp >= startTime, "start time not set");
        require(
            block.timestamp >= lastClaimTime.add(CLAIM_DELAY),
            "delay since last claim not passed"
        );
        if (block.timestamp > END_DAY) {
            claimDust();
        } else {
            uint256 currentEpoch = getCurrentEpoch(); // get current epoch
            if (currentEpoch > epoch) {
                uint256 multiplier = currentEpoch.sub(epoch);
                KeytangoToken.safeTransfer(
                    beneficiary,
                    RELEASEAMOUNT.mul(multiplier)
                );
                epoch = epoch.add(multiplier);
            } else {
                KeytangoToken.safeTransfer(beneficiary, RELEASEAMOUNT);
                epoch = epoch.add(1);
            }

            lastClaimTime = block.timestamp;
            emit Claimed(RELEASEAMOUNT, epoch);
        }
    }

    function getClaimAmount() external view returns (uint256) {
        uint256 currentEpoch = getCurrentEpoch(); // get current epoch
        if (currentEpoch > epoch) {
            uint256 multiplier = currentEpoch.sub(epoch);
            return RELEASEAMOUNT.mul(multiplier);
        } else {
            return RELEASEAMOUNT;
        }
    }

    function claimDust() public {
        require(block.timestamp >= END_DAY, "Vesting not yet finished");
        KeytangoToken.safeTransfer(
            beneficiary,
            KeytangoToken.balanceOf(address(this))
        );
    }

    function setBeneficiary(address _addy) external {
        require(msg.sender == beneficiary);
        beneficiary = _addy;
    }
}