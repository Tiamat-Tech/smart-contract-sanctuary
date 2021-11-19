pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/compound-protocol/CTokenInterface.sol";

contract IRSwap {

  using SafeMath for uint256;
  
  address public cTokenAddress;
  uint8 public initLeverage; //leverage here is the reciprocal of initial margin ratio
  uint8 public maintLeverage; //leverage here is the reciprocal of maintenance margin ratio
  
  IRSwapSpec[] swaps;
  
  struct IRSwapSpec {
    uint256 startBlock;
    uint256 endBlock;
    uint256 notional;
    uint256 initCTokenRate;
    uint256 fixedRatePerBlock;
    address addressPayer;
    uint256 fundingPayer;
    uint256 accruedInterestPayer;
    address addressReceiver;
    uint256 fundingReceiver;
    uint256 accruedInterestReceiver;
  }
  
  constructor(address _cTokenAddress, uint8 _initLeverage, uint8 _maintLeverage) public {
    cTokenAddress = _cTokenAddress;
    initLeverage = _initLeverage;
    maintLeverage = _maintLeverage;
  }

  function getCTokenRate() public view returns(uint256, uint256) {
    return (CTokenInterface(cTokenAddress).exchangeRateStored(), block.number);
  }

  function pingCompound() public {
    CTokenInterface(cTokenAddress).accrueInterest();
  }

  function createSwap(
                      uint256 notional,
                      uint256 endBlock,
                      uint256 fixedRatePerBlock,
                      address addressPayer,
                      uint256 fundingPayer,
                      address addressReceiver,
                      uint256 fundingReceiver
                      ) public {
    require(notional > 0, "notional too small");
    require(endBlock > block.number, "endBlock must be in future");
    require(fundingPayer > notional.div(initLeverage), "funding below initMargin");
    require(fundingReceiver > notional.div(initLeverage), "funding below initMargin");

    (uint256 initCTokenRate, ) = getCTokenRate();
    IRSwapSpec memory swap = IRSwapSpec(block.number,
                                 endBlock,
                                 notional,
                                 initCTokenRate,
                                 fixedRatePerBlock,
                                 addressPayer,
                                 fundingPayer,
                                 0,
                                 addressReceiver,
                                 fundingReceiver,
                                 0
                                 );
    swaps.push(swap);
  }

  function accrueInterest(uint256 i) public {
    require(i < swaps.length, "index out of bounds");
    IRSwapSpec storage swap = swaps[i];
    (uint256 currentCTokenRate, uint256 currentBlock) = getCTokenRate();
    swap.accruedInterestPayer = swap.notional.mul(currentCTokenRate).div(swap.initCTokenRate);
    uint256 accruedInterestReceiver = swap.notional;
    uint256 periods = currentBlock.sub(swap.startBlock);
    uint256 mantissa = 1e18;  //fixedRatePerBlock by convention is eighteen decimals
    for(uint j=0; j < periods; j++) {
      accruedInterestReceiver = accruedInterestReceiver.mul(mantissa + swap.fixedRatePerBlock).div(mantissa);
    }
    accruedInterestReceiver = accruedInterestReceiver - swap.notional;
    swap.accruedInterestReceiver = accruedInterestReceiver;
  }

  //READ FUNCTIONS
  function getSwapSpec(uint256 i) public view returns(
                                                      uint256,
                                                      uint256,
                                                      uint256,
                                                      uint256,
                                                      uint256,
                                                      address,
                                                      uint256,
                                                      uint256,
                                                      address,
                                                      uint256,
                                                      uint256
                                                      ) {
    require(i < swaps.length, "index out of bounds");
    IRSwapSpec memory swap = swaps[i];
    return (swap.startBlock,
            swap.endBlock,
            swap.notional,
            swap.initCTokenRate,
            swap.fixedRatePerBlock,
            swap.addressPayer,
            swap.fundingPayer,
            swap.accruedInterestPayer,
            swap.addressReceiver,
            swap.fundingReceiver,
            swap.accruedInterestReceiver
            );
  }
}