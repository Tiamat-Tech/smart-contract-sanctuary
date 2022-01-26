// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (finance/VestingWallet.sol)
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./utils/AddressVestingPeriodClaimed.sol";
import "./utils/VestingPeriod.sol";
import "./interfaces/IVestingWallet.sol";

/**
 * @title VestingWallet
 * @dev This contract handles the vesting of ERC20 tokens for a group of beneficiaries. Custody of multiple tokens
 * can be given to this contract, which will release the token to the beneficiary following a given vesting schedule.
 * The vesting schedule is customizable through the {vestedAmount} function.
 *
 * Any token transferred to this contract will follow the vesting schedule as if they were locked from the beginning.
 * Consequently, if the vesting has already started, any amount of tokens sent to this contract will (at least partly)
 * be immediately releasable.
 */
contract VestingWallet {
    event ERC20Released(address indexed token, uint256 amount);
    event Timestamp(uint256 vestingPeriodStart, uint256 vestingPeriodEnd, uint256 currentTimestamp);
    mapping(address => AddressVestingPeriodClaimed[]) private _erc20Released;
    uint256 constant firstVestingPeriodAllocationPercentage = 40000000000000000;
    uint256 constant secondVestingPeriodAllocationPercentage = 80000000000000000;
    VestingPeriod[] private vestingPeriods;
    address token;

    /**
     * @dev Set the beneficiary, start timestamp and vesting duration of the vesting wallet.
     */
    constructor(uint256 _firstVestingPeriodStart, uint256 _firstVestingPeriodDuration, uint256 _secondVestingPeriodStart, uint256 _secondVestingPeriodDuration) {
        vestingPeriods.push(VestingPeriod({
                id: 1,
                start: _firstVestingPeriodStart,
                duration: _firstVestingPeriodDuration,
                allocationPercentage: firstVestingPeriodAllocationPercentage
        }));
        vestingPeriods.push(VestingPeriod({
                id: 2,
                start: _secondVestingPeriodStart,
                duration: _secondVestingPeriodDuration,
                allocationPercentage: secondVestingPeriodAllocationPercentage
        }));
    }
    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable {}
    /**
     * @dev Set the address of token that is being vested .
     */
    function setVestedTokenAddress(address _token) public{
        token = _token;
    }
    /**
     * @dev Getter for the currenly active vesting period start timestamp.
     */
    // was before
    // function start() public returns (uint256) {
    //     return currentlyActivePeriod().start;
    // }
    function start() public returns (uint256) {
        return vestingPeriods[0].start;
    }
    /**
     * @dev Getter for the currently active vesting period duration.
     */
    function duration() public view returns (uint256) {
        return vestingPeriods[vestingPeriods.length-1].duration;
    }
    /**
     * @dev Currently active vesting period
     */
    function currentlyActivePeriod() public returns (VestingPeriod memory){
        for(uint256 i = 0; i < vestingPeriods.length; i++){
            if (block.timestamp >= vestingPeriods[i].start && block.timestamp <= vestingPeriods[i].start + vestingPeriods[i].duration){
                emit Timestamp(vestingPeriods[i].start, vestingPeriods[i].start + vestingPeriods[i].duration, block.timestamp);
                return vestingPeriods[i];
            }
        }
    }
    /**
     * @dev Amount of recipient's tokens already released
     */
    function released(address recipient) public returns (uint256) {
        // VestingPeriod memory currentlyActivePeriod = currentlyActivePeriod();
        AddressVestingPeriodClaimed[] memory recipientErc20Releases = _erc20Released[recipient];
        uint256 recipientErc20ReleasesSummation = 0;
        if (recipientErc20Releases.length > 0){
            for(uint256 i = 0; i < recipientErc20Releases.length; i++){
                if(recipientErc20Releases[i].vestingPeriodId !=0){
                    recipientErc20ReleasesSummation+=recipientErc20Releases[i].claimed;
                }
                else{
                    recipientErc20ReleasesSummation+=0;
                }
            }
        }
        else return 0;
    }
    /**
     * @dev Amount of recipient's tokens already released
     */
    function getRecipientReleasedForCurrentPeriod(address recipient, uint256 periodId) public returns (uint256){
        AddressVestingPeriodClaimed[] memory recipientErc20Releases = _erc20Released[recipient];
        if(recipientErc20Releases.length > 0){
            for(uint256 i = 0; i < recipientErc20Releases.length; i++){
                if(recipientErc20Releases[i].vestingPeriodId == periodId){
                    return recipientErc20Releases[i].vestingPeriodId;
                }
                else return 0;
            }
        }
    }
    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokensReleased} event.
     */
    function release(address recipient, uint256 totalAllocation) public{
        // should add only treasury;
        VestingPeriod memory currentlyActivePeriod = currentlyActivePeriod();
        uint256 recipientVestingPeriodClaimedId = getRecipientReleasedForCurrentPeriod(recipient, currentlyActivePeriod.id);
        // uint256 releasable = vestedAmount(uint64(block.timestamp), recipient, totalAllocation) - released(recipient);
        // if(recipientVestingPeriodClaimedId == 0){
        //     AddressVestingPeriodClaimed memory claim = AddressVestingPeriodClaimed({
        //         vestingPeriodId: currentlyActivePeriod.id,
        //         claimed: releasable
        //     });
        //     _erc20Released[recipient].push(claim);
        // }
        // else {
        //     _erc20Released[recipient][recipientVestingPeriodClaimedId].claimed+=releasable;
        // }
        // emit ERC20Released(token, releasable);
        // SafeERC20.safeTransfer(IERC20(token), recipient, releasable);
    }
    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(uint64 timestamp, address recipient,uint256 totalAllocation) public returns (uint256) {
        return _vestingSchedule(totalAllocation + released(recipient), timestamp);
    }
    /**
     * @dev Virtual implementation of the vesting formula. This returns the amout vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) public returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            uint256 totalAllocationSummation = 0;
            // VestingPeriod memory currentlyActivePeriod = currentlyActivePeriod();
            // for(uint256 i = 0; i < vestingPeriods.length; i++){
            //     if(vestingPeriods[i].id != currentlyActivePeriod.id){
            //         totalAllocationSummation += ( totalAllocation * vestingPeriods[i].allocationPercentage * (vestingPeriods[i].duration - vestingPeriods[i].start));
            //     }
            //     else{
            //         totalAllocationSummation += ( totalAllocation * currentlyActivePeriod.allocationPercentage * (timestamp - start())) / currentlyActivePeriod.duration;
            //     }
            // }
            return totalAllocationSummation;
        }
    }
}