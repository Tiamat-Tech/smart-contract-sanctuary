// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AOC01 is ERC20 {

  constructor(uint256 initialSupply) ERC20("AdventOfCode01", "AOC01") {
    _mint(msg.sender, initialSupply);
  }

  function decimals() public pure override returns (uint8) {
    return 0;
  }

  /*
   * Burns all coins in the users wallet
   * then solves part 1 of AOC 2021 Day 1 based on the input data
   * and mints the respective amount of coints for the user.
   */
  function part1(uint256[] memory input) public {
    _burn(msg.sender, balanceOf(msg.sender));
    uint256 solution = 0;
    uint256 i;

    for (i = 1; i < input.length; i++) {
      if (input[i] > input[i - 1]) {
        solution = solution + 1;
      }
    }

    _mint(msg.sender, solution);
  }

  /*
   * Burns all coins in the users wallet
   * then solves part 2 of AOC 2021 Day 1 based on the input data
   * and mints the respective amount of coints for the user.
   */
  function part2(uint256[] calldata input) public {
    uint256 i;
    uint256[] memory aggregated;
    aggregated = new uint[](input.length - 2);

    for (i = 0; i < input.length - 2; i++) {
      aggregated[i] = input[i] + input[i+1] + input[i+2];
    }

    part1(aggregated);
  }
}