pragma solidity 0.7.3;

import "../AlphaStrategy.sol";

contract StrategyEthUsdt is AlphaStrategy {

  constructor() public {}

  function initialize(
    address _storage,
    address _vault,
    address _tAlpha
  ) public initializer {
    AlphaStrategy.initializeAlphaStrategy(
      _storage,
      address(0x06da0fd433C1A5d7a4faa01111c044910A184553), // underlying usdt/eth
      _vault,
      address(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd), // slpRewardPool - master chef contract
      0,  // SLP Pool id
      address(0x168F8469Ac17dd39cd9a2c2eAD647f814a488ce9), // onxFarmRewardPool
      15,
      address(0xE0aD1806Fd3E7edF6FF52Fdb822432e847411033), // onx
      address(0xa99F0aD2a539b2867fcfea47F7E71F240940B47c), // stakedOnx
      address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2), // sushi
      address(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272), // xSushi
      _tAlpha
    );
  }
}