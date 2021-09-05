pragma solidity ^0.5.17;

import {Deposit} from "@keep-network/tbtc/contracts/deposit/Deposit.sol";
import {DepositStates} from "@keep-network/tbtc/contracts/deposit/DepositStates.sol";
import {TBTCDepositToken} from "@keep-network/tbtc/contracts/system/TBTCSystem.sol";
import {Initializable} from '@openzeppelin/upgrades/contracts/Initializable.sol';

import "./DepositRedemptionIncentiveFactoryAuthority.sol";

// A deposit redemption incentive is a bonus that is available to the owner of
// the tdt (the redeemer) once the tdt enters either the REDEEMED or LIQUIDATED
// state. The owner of the incentive can optionally choose to cancel their
// incentive at any time, at which point a ~7 day timer starts. At the end of
// these 7 days, the incentive owner can receive the incentive they provided
// back. This ensures any in process redemptions still receive their promised
// bonuses.
contract DepositRedemptionIncentive is DepositRedemptionIncentiveFactoryAuthority {

    address payable creator;
    Deposit deposit;
    TBTCDepositToken tbtcDepositToken;

    uint constant CANCELLATION_COOL_DOWN_SECONDS = 60 * 60 * 24 * 7;
    uint constant MAX_INT = uint256(-1);
    uint cancellationBlockTimestamp = MAX_INT;

    // Setup a deposit incentive pointing at a specific address. Any amount can be deposited (by anyone).
    function initializeIncentive(
        address payable _creator,
        address payable _tbtcDepositAddress,
        TBTCDepositToken _tbtcDepositToken
    ) public onlyFactory payable {
        creator = _creator;
        deposit = Deposit(_tbtcDepositAddress);
        tbtcDepositToken = TBTCDepositToken(_tbtcDepositToken);
    }

    function isInEndState() private view returns (bool) {
        return deposit.currentState() == uint256(DepositStates.States.REDEEMED) || deposit.currentState() == uint256(DepositStates.States.LIQUIDATED);
    }

    // Send the redemption bonus to the owner of the tdt. Contract must be in
    // an end state.
    function redeem() public {
        require(isInEndState());

        address payable tdtOwner = address(uint160(tbtcDepositToken.ownerOf(uint256(address(deposit)))));
        selfdestruct(tdtOwner);
    }

    modifier onlyCreator() {
        require(msg.sender == creator); // If it is incorrect here, it reverts.
        _;                              // Otherwise, it continues.
    } 

    function initCancel() public onlyCreator {
        cancellationBlockTimestamp = block.timestamp + CANCELLATION_COOL_DOWN_SECONDS;
    }

    function finalizeCancel() public {
        require(!isInEndState());
        require(block.timestamp > cancellationBlockTimestamp);

        selfdestruct(creator);
    }

    function addIncentive() public payable {}
}