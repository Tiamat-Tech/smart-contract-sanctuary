pragma solidity ^0.5.17;

import {TBTCDepositToken} from "@keep-network/tbtc/contracts/system/TBTCSystem.sol";

import {CloneFactory} from "./CloneFactory.sol";
import {DepositRedemptionIncentive} from "./DepositRedemptionIncentive.sol";

contract DepositRedemptionIncentiveFactory is CloneFactory {
  address public implementationContract;
  TBTCDepositToken public tbtcDepositToken;

  event IncentiveCreated(address cloneAddress);

  constructor (address _implementationContract, TBTCDepositToken _tbtcDepositToken) public {
    implementationContract = _implementationContract;
    tbtcDepositToken = _tbtcDepositToken;
  }

  function createIncentive(address payable _tbtcDepositAddress) payable public returns (address){
    address cloneAddress = createClone(implementationContract);
    emit IncentiveCreated(cloneAddress);

    DepositRedemptionIncentive incentive = DepositRedemptionIncentive(address(uint160(cloneAddress)));
    incentive.initialize(address(this));

    incentive.initializeIncentive.value(msg.value)(msg.sender, _tbtcDepositAddress, tbtcDepositToken);
    return cloneAddress;
  }
}