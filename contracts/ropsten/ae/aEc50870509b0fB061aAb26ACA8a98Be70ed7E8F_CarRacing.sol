// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./CarHelper.sol";

contract CarRacing is CarHelper {
  uint randNonce = 0;
  uint RaceWinningProbability = 70;

  function randMod(uint _modulus) internal returns(uint) {
    randNonce = randNonce++;
    return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % _modulus;
  }

  function startRacing(uint _carId, uint _targetId) external onlyOwnerOf(_carId) {
    Car storage myCar = cars[_carId];
    Car storage enemyCar = cars[_targetId];
    uint rand = randMod(100);
    if (rand <= RaceWinningProbability) {
      myCar.winCount = myCar.winCount++;
      myCar.carLevel = myCar.carLevel++;
      enemyCar.lossCount = enemyCar.lossCount++;
      levelUpCar(_carId, enemyCar.dna);
    } else {
      myCar.lossCount = myCar.lossCount++;
      enemyCar.winCount = enemyCar.winCount++;
      _triggerCooldown(myCar);
    }
  }

}