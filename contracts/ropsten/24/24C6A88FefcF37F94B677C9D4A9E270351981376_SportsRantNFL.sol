// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SportsRantNFL is Ownable {
  using SafeMath for uint256;

  // uint256 constant ENTRY_WEI = 50000000000000000000; // 50 eth/matic
  uint256 constant ENTRY_WEI = 500;

  // Intake counts
  uint256 rake; // 10%
  uint256 jackpotTally; // 20%
  uint256 roundWinnings; // 70%

  function getRakeTotal() public view onlyOwner returns (uint256) {
    return rake;
  }

  function getJackpotTotal() public view returns (uint256) {
    return jackpotTally;
  }

  function getRoundWinnings() public view returns (uint256) {
    return roundWinnings;
  }

  struct RoundPick {
    bool PicksMade;
    bool PaidOut;
    uint32 Picks;
  }

  mapping(address => mapping(uint8 => RoundPick)) playerPicks;

  function makePicks(uint8 _round, uint32 _picks) public payable {
    require(
      !playerPicks[msg.sender][_round].PicksMade,
      "Already made your picks"
    );
    require(msg.value == ENTRY_WEI, "Need 50 matic to make picks");

    // TODO: Make sure time hasn't expired

    // Add 20% of entry to finals jackpot tally
    uint256 oneTenth = msg.value.div(10);
    rake.add(oneTenth);
    jackpotTally.add(oneTenth.mul(2));
    roundWinnings.add(oneTenth.mul(7));

    playerPicks[msg.sender][_round].PicksMade = true;
    playerPicks[msg.sender][_round].Picks = _picks;

    // emit stuff
  }

  function changePicks(uint8 _round, uint32 _picks) public payable {
    require(
      playerPicks[msg.sender][_round].PicksMade,
      "You haven't made picks"
    );

    // TODO: Make sure time hasn't expired

    playerPicks[msg.sender][_round].Picks = _picks;

    // emit stuff
  }

  function getSenderPicks(uint8 _round) public view returns (uint32) {
    require(
      playerPicks[msg.sender][_round].PicksMade,
      "You haven't made picks"
    );
    return playerPicks[msg.sender][_round].Picks;
  }

  // Payback functions

  function payEntryBack(
    address payable _to,
    uint8 _round,
    uint32 _picks
  ) public onlyOwner {
    uint256 amount = ENTRY_WEI;
    payBack(_to, _round, _picks, amount);
  }

  function payDoubleEntryBack(
    address payable _to,
    uint8 _round,
    uint32 _picks
  ) public onlyOwner {
    uint256 amount = ENTRY_WEI * 2;
    payBack(_to, _round, _picks, amount);
  }

  function payBack(
    address payable _to,
    uint8 _round,
    uint32 _picks,
    uint256 _amount
  ) private onlyOwner {
    require(
      playerPicks[msg.sender][_round].PicksMade,
      "They haven't made picks"
    );
    require(
      !playerPicks[msg.sender][_round].PaidOut,
      "Already paid out for that round"
    );
    require(
      playerPicks[msg.sender][_round].Picks == _picks,
      "Picks appear to be different"
    );
    require(roundWinnings.sub(_amount) >= 0, "Picks appear to be different");

    playerPicks[msg.sender][_round].PaidOut = true;

    roundWinnings = roundWinnings.sub(_amount);
    _to.transfer(_amount);

    // emit stuff
  }
}