// SPDX-License-Identifier: MIT
// curion.eth, Jan 2022, for highly immersive metaverse purposes
// contact: [email protected]

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
//import "@openzeppelin/contracts/access/Roles.sol";
//import "@openzeppelin/contracts/utils/Address.sol";
//import "@openzeppelin/contracts/security/PullPayment.sol"; //does this mean I have to include escrow? likely not as it imports it already...

contract ticTacToe is Ownable, ReentrancyGuard, Pausable {

 //--------------------declaration of independence, i mean, variables--------------------
  address public admin;
  address public charityAddress;
  bool public charityClaimIsOpen = false;
  uint256 public entryFee = 0.1 * 10**18; //default AVAX (maybe MOVR, later) amount required to play
  
  uint256 public totalContractWinnings = 0; //total amount of winnings awarded all-time
  uint256 public totalContractUnclaimedWinnings = 0; //total amount of winnings reserved in contract. Shouldnt withdraw beyond contractBalance-totalContractUnclaimedWinnings
  uint256 public winningPerc = 150; //percenage of individual entryFee awarded to winner.
  uint256 public percToCharity = 0; //percentage of total 'pot' sent to charity, the remainder being sent to owner or being kept in wallet
  uint256 public percToOwner = 50; //project dev fund. not just being greedy lol. trying not to over-grab anyway...only whole number percentages!
  uint256 public percSum = percToCharity+percToOwner; //for checking claim amounts
  
  uint256 public blocksBetweenUpdate = 2400; //approx 8 hours.
  uint256 public creationBlock;
  uint256 public lastUpdateBlock = 0; //initialization
  
  uint256 public prevTotalClaimableRewards = 0;
  uint256 public thisTotalClaimableRewards = 0;
  uint256 public donationClaimableRewards = 0;
  uint256 public ownerClaimableRewards = 0;

  mapping(address => uint256) winnings;

 //--------------------------------------constructor, misc-------------------------------------
  constructor(address _admin) {
    admin = payable(_admin);
    creationBlock = block.number; //ik this isn't advisable, but I've included param to adjust num blocks bt updates
  }

  //backup payable functions (needed?)
  // Function to receive Ether. msg.data must be empty
  receive() external payable {}
  // Fallback function is called when msg.data is not empty
  fallback() external payable {}

  //------------------------------functions that MOVE MONEY------------------------------

  function payEntryFee(uint256 _entryFee) external payable {
    require(msg.value == entryFee, "Wrong amount sent"); //should this be == or >=? don't think this has anything to do with gas.
  }

  function updateClaimable() public nonReentrant whenNotPaused {
    //every N blocks, update reward balance by those accrued between blocks X and Y with N blocks between them
    //relies on contract interactions to call this function and update the winnings, so timing may not be exact, but the server can call this periodically too
    if(lastUpdateBlock==0) {lastUpdateBlock = creationBlock; prevTotalClaimableRewards = 0;}
    if(block.number-lastUpdateBlock > blocksBetweenUpdate) {
      // divide up rewards accrued since last time this statement was entered. get total since last update, split, define new start to mark next range N blocks later.
      thisTotalClaimableRewards = address(this).balance - totalContractUnclaimedWinnings - prevTotalClaimableRewards; //isolate claimable rewards since last claim
      donationClaimableRewards += thisTotalClaimableRewards * percToCharity;
      ownerClaimableRewards += thisTotalClaimableRewards * percToOwner;
      prevTotalClaimableRewards += thisTotalClaimableRewards;
      lastUpdateBlock = block.number; //reset lastUpdateBlock to current block
    }
  }

  function claimWinnings(address payable _winningsClaimer) external nonReentrant whenNotPaused {
    require(_winningsClaimer != address(0), "Not valid address");
    require(msg.sender == _winningsClaimer,"Claiming for wrong address");
    require(winnings[_winningsClaimer] > 0, "no rewards to claim");
    uint256 claimableWinnings = winnings[_winningsClaimer];
    winnings[_winningsClaimer]=0;
    totalContractUnclaimedWinnings -= winnings[_winningsClaimer]; //decrease unclaimed reward total
    (bool success, ) = _winningsClaimer.call{ value: claimableWinnings }("");
    require(success, "winnings claim fail");
    updateClaimable();
  }

  function claimDonation(address payable _charityAddress) external nonReentrant whenNotPaused {
    require(_charityAddress != address(0), "Not valid address");
    require(charityClaimIsOpen,"Charity claim is not currently open");
    require(msg.sender == charityAddress && _charityAddress == charityAddress, "Not selected charity, can't claim charity rewards!");
    require(percSum<=100, "Check claim distribution percentages and correct such that they add to less than 100");
    uint256 donation = donationClaimableRewards;
    donationClaimableRewards = 0;
    (bool success, ) = _charityAddress.call{ value: donation }("");
    require(success, "donation claim fail");
    updateClaimable();
  }

  function ownerClaimRewards(uint256 _ownerClaimableRewards) external onlyOwner nonReentrant whenNotPaused {
    require(percSum<=100, "Check claim distribution percentages and correct such that they add to less than 100");
    uint256 ownerClaimAmount = ownerClaimableRewards;
    ownerClaimableRewards = 0;
    (bool success, ) = msg.sender.call{ value: ownerClaimAmount }("");
    require(success, "owner claim fail");
    updateClaimable();
  }

  function withdraw(uint256 _withdrawAmount) external onlyOwner nonReentrant whenNotPaused {   
    require(_withdrawAmount < address(this).balance, "Invalid withdraw amount, not sure if this is redundant...");
    (bool success, ) = msg.sender.call{ value: _withdrawAmount }("");
    require(success, "withdraw fail");
    updateClaimable();
  }

  //-------------------------READING and SET PARAMETER functions--------------------------
  
  // read/set functions
  function getBalance() public view whenNotPaused returns (uint256) {
      return address(this).balance;
  }
  function readTotalContractWinnings() public view whenNotPaused returns (uint256) {
    return totalContractWinnings;
  }
  function setEntryFee(uint256 _entryFee) public onlyOwner whenNotPaused returns (uint256) {
    entryFee = _entryFee;
  }
  function setPercToCharity(uint256 _percToCharity) public onlyOwner whenNotPaused returns (uint256) {
    percToCharity = _percToCharity;
  }
  function setPercToOwner(uint256 _percToOwner) public onlyOwner whenNotPaused returns (uint256) {
    percToOwner = _percToOwner;
  }
  function setBlockBetweenRewardUpdates(uint256 _blocksBetweenUpdate) public onlyOwner whenNotPaused returns(uint256) {
    blocksBetweenUpdate = _blocksBetweenUpdate;
  }

  // so the webapp can read the amount claimable
  function claimableGameWinnings(address _playerAddress) public view whenNotPaused returns (uint256){
    return winnings[_playerAddress];
  }

  function updateGameWinnings(address _winnerAddress) public onlyOwner nonReentrant whenNotPaused { //make payable?
    winnings[_winnerAddress] += entryFee * (winningPerc/100); //1.5x entryFee to winner
    totalContractWinnings += winnings[_winnerAddress]; //add to total amount of winnings awarded overall
    totalContractUnclaimedWinnings += winnings[_winnerAddress]; //add to current amount of unclaimed winnings
    updateClaimable();
  }

  function toggleCharityClaim() public onlyOwner whenNotPaused returns (bool){
    charityClaimIsOpen = !charityClaimIsOpen;
  }

  function setCharityAddress(address _charityAddress) public onlyOwner whenNotPaused {
    charityAddress = _charityAddress;
  }

}