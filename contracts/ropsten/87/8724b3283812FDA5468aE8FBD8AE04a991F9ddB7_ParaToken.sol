//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ParaToken is ERC20, Ownable {
  uint256 private constant _supply = 10e7 ether;
  uint256 private constant _vestingPeriod = 31536000;
  uint256 private constant _vestingRate = _supply / _vestingPeriod; // amount that vests per second
  uint256 private immutable _start;
  address private immutable _wallet;

  uint256 private _claimed = 0;

  constructor(address wallet) ERC20("Para", "PRA") {
    _start = block.timestamp;
    _wallet = wallet;
    _mint(wallet, 9 * _supply);
  }

  function checkClaim() external view returns (uint256 ret) {
    uint256 elapsedTime = block.timestamp - _start;

    uint256 claim;
    if (elapsedTime >= _vestingPeriod) {
      claim = _supply - _claimed;
    } else {
      claim = (_vestingRate * elapsedTime) - _claimed;
    }

    return claim;
  }

  function claimOutstanding() external onlyOwner {
    require(_claimed < _supply, "already claimed the supply amount");

    uint256 elapsedTime = block.timestamp - _start;

    uint256 claim;
    if (elapsedTime >= _vestingPeriod) {
      claim = _supply - _claimed;
    } else {
      claim = (_vestingRate * elapsedTime) - _claimed;
    }

    _claimed = _claimed + claim;
    _mint(_wallet, claim);
  }
}