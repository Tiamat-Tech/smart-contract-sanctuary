// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./DeathRow.sol";
import "./BULLIES.sol";
import "./IPayroll.sol";

contract Payroll is Ownable, IERC721Receiver, Pausable, IPayroll {
  using EnumerableSet for EnumerableSet.UintSet; 

  // maximum medals score for a Bear
  uint8 public constant MAX_MEDALS = 5;

  // struct to store a stake's token, owner, and earning values
  struct Stake {
    uint16 tokenId;
    uint80 value;
    address owner;
  }

  event TokenStaked(address owner, uint256 tokenId, uint256 value);
  event BullClaimed(uint256 tokenId, uint256 earned, bool unstaked);
  event BearClaimed(uint256 tokenId, uint256 earned, bool unstaked);

  // reference to the DeathRow NFT contract
  DeathRow deathRow;
  // reference to the $BULLIES contract for minting $BULLIES earnings
  BULLIES bullies;

  // maps tokenId to stake
  mapping(uint256 => Stake) public payroll; 
  // maps medals to all Bears stakes with that gang
  mapping(uint256 => Stake[]) public guards; 
  // tracks location of each Bears in the prison
  mapping(uint256 => uint256) public guardIndices; 
  // tracks token owned by owners
  mapping(address => EnumerableSet.UintSet) private _deposits;
  // total gang scores staked
  uint256 public totalGangStaked = 0; 
  // any rewards distributed when no Bears are stacked
  uint256 public unaccountedRewards = 0; 
  // amount of $BULLIES due for each medal point staked
  uint256 public bulliesPerMedal = 0; 

  // Bulls earn 10000 $BULLIES per day 
  uint256 public constant DAILY_BULLIES_RATE = 10000 ether;
  // sheep must have 2 days worth of $BULLIES to unstake or else it's too cold
  uint256 public constant MINIMUM_TO_EXIT = 5 minutes;
  // Bears take a 20% tax on all $BULLIES claimed
  uint256 public constant BULLIES_CLAIM_TAX_PERCENTAGE = 20;
  // there will only ever be (roughly) 2.4 billion $BULLIES earned through staking
  uint256 public constant MAXIMUM_GLOBAL_BULLIES = 2400000000 ether;

  // amount of $BULLIES earned so far
  uint256 public totalBulliesEarned;
  // number of Bulls staked in the Barn
  uint256 public totalBullsStaked;
  // the last time $BULLIES was claimed
  uint256 public lastClaimTimestamp;

  // emergency rescue to allow unstaking without any checks but without $BULLIES
  bool public rescueEnabled = false;

  /**
   * @param _deathRow reference to the DeathRow NFT contract
   * @param _bullies reference to the $BULLIES token
   */
  constructor(address _deathRow, address _bullies) { 
    deathRow = DeathRow(_deathRow);
    bullies = BULLIES(_bullies);
  }

  /** STAKING */

  function depositsOf(address account) external view returns (uint256[] memory) {
    EnumerableSet.UintSet storage depositSet = _deposits[account];
    uint256[] memory tokenIds = new uint256[] (depositSet.length());

    for (uint256 i; i < depositSet.length(); i++) {
      tokenIds[i] = depositSet.at(i);
    }

    return tokenIds;
  }

  /**
   * adds Bulls and Bears to the Barn and Pack
   * @param account the address of the staker
   * @param tokenIds the IDs of the Bulls and Bears to stake
   */
  function addManyToPayroll(address account, uint16[] calldata tokenIds) override external {
    require(account == _msgSender() || _msgSender() == address(deathRow), "Don't give your tokens to other inmates!");
    for (uint i = 0; i < tokenIds.length; i++) {
      if (_msgSender() != address(deathRow)) { // dont do this step if its a mint + stake
        require(deathRow.ownerOf(tokenIds[i]) == _msgSender(), "Not your token dirty criminal");
        deathRow.transferFrom(_msgSender(), address(this), tokenIds[i]);
      } else if (tokenIds[i] == 0) {
        continue; // there may be gaps in the array for stolen tokens
      }

      if (isBull(tokenIds[i])) 
        _addBullsToPayroll(account, tokenIds[i]);
      else 
        _addBearToGuards(account, tokenIds[i]);
    }
  }

  /**
   * adds a single Bull to the Payroll
   * @param account the address of the staker
   * @param tokenId the ID of the Bulls to add to the Barn
   */
  function _addBullsToPayroll(address account, uint256 tokenId) internal whenNotPaused _updateEarnings {
    payroll[tokenId] = Stake({
      owner: account,
      tokenId: uint16(tokenId),
      value: uint80(block.timestamp)
    });
    totalBullsStaked += 1;
    emit TokenStaked(account, tokenId, block.timestamp);
    _deposits[account].add(tokenId);
  }

  /**
   * adds a single Bear to the Guards
   * @param account the address of the staker
   * @param tokenId the ID of the Bear to add to the Guards
   */
  function _addBearToGuards(address account, uint256 tokenId) internal {
    uint256 medals = _medalsForBear(tokenId);
    totalBullsStaked += medals; // Portion of earnings ranges from 1 to 5
    guardIndices[tokenId] = guards[medals].length; // Store the location of the bear in the prison
    guards[medals].push(Stake({
      owner: account,
      tokenId: uint16(tokenId),
      value: uint80(bulliesPerMedal)
    })); // Add bear to the guards
    emit TokenStaked(account, tokenId, bulliesPerMedal);
    _deposits[account].add(tokenId);
  }

  /** CLAIMING / UNSTAKING */

  /**
   * realize $BULLIES earnings and optionally unstake tokens from the Barn / Pack
   * to unstake a Bulls it will require it has 2 days worth of $BULLIES unclaimed
   * @param tokenIds the IDs of the tokens to claim earnings from
   * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
   */
  function claimManyFromPayrollAndPack(uint16[] calldata tokenIds, bool unstake) external whenNotPaused _updateEarnings {
    uint256 owed = 0;
    for (uint i = 0; i < tokenIds.length; i++) {
      if (isBull(tokenIds[i]))
        owed += _claimBullsFromPayroll(tokenIds[i], unstake);
      else
        owed += _claimBearFromPack(tokenIds[i], unstake);
    }
    if (owed == 0) return;
    bullies.mint(_msgSender(), owed);
  }

  /**
   * realize $BULLIES earnings for a single Bulls and optionally unstake it
   * if not unstaking, pay a 20% tax to the staked Bears
   * if unstaking, there is a 50% chance all $BULLIES is stolen
   * @param tokenId the ID of the Bulls to claim earnings from
   * @param unstake whether or not to unstake the Bulls
   * @return owed - the amount of $BULLIES earned
   */
  function _claimBullsFromPayroll(uint256 tokenId, bool unstake) internal returns (uint256 owed) {
    Stake memory stake = payroll[tokenId];
    require(stake.owner == _msgSender(), "That's why you're in prison");
    require(!(unstake && block.timestamp - stake.value < MINIMUM_TO_EXIT), "Too early to exit");

    owed = calcRewardBull(tokenId);

    if (unstake) {
      if (random(tokenId) & 1 == 1) { // 50% chance of all $BULLIES stolen
        _payBearTax(owed);
        owed = 0;
      }
      deathRow.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Bulls
      delete payroll[tokenId];
      totalBullsStaked -= 1;
    } 
    else {
      uint256 taxPercentage = calcBullTaxPercentage(tokenId);
      _payBearTax(owed * taxPercentage / 100); // percentage tax to staked wolves
      owed = owed * (100 - taxPercentage) / 100; // remainder goes to Bull owner
      payroll[tokenId] = Stake({
        owner: _msgSender(),
        tokenId: uint16(tokenId),
        value: uint80(block.timestamp)
      }); // reset stake

      _deposits[_msgSender()].remove(tokenId);
    }
    emit BullClaimed(tokenId, owed, unstake);
  }

  function calculateReward(uint16[] calldata tokenIds) public view returns (uint256 owed) {

    for (uint i = 0; i < tokenIds.length; i++) {
      if (isBull(tokenIds[i]))
        owed += calcRewardBull(tokenIds[i]);
      else
        owed += calcRewardBear(tokenIds[i]);
    }
  }

  function calcRewardBull(uint256 tokenId) public view returns (uint256 owed) {
    Stake memory stake = payroll[tokenId];

    if (totalBulliesEarned < MAXIMUM_GLOBAL_BULLIES) {
        owed = (block.timestamp - stake.value) * DAILY_BULLIES_RATE / 1 days;
    } else if (stake.value > lastClaimTimestamp) {
        owed = 0; 
    } else {
        owed = (lastClaimTimestamp - stake.value) * DAILY_BULLIES_RATE / 1 days; 
    }
  }


  function calcRewardBear(uint256 tokenId) public view returns (uint256 owed) {
    uint256 medals = _medalsForBear(tokenId);
    Stake memory stake = guards[medals][guardIndices[tokenId]];
    require(stake.owner == _msgSender(), "Go away thief");
    owed = (medals) * (bulliesPerMedal - stake.value); 
  }

  function calcBullTaxPercentage(uint256 tokenId) public view returns (uint256 percentage) {
    percentage = 100 - BULLIES_CLAIM_TAX_PERCENTAGE - _gangForBull(tokenId);
  }

  /**
   * realize $BULLIES earnings for a single Bear and optionally unstake it
   * Bears earn $BULLIES proportional to their medals
   * @param tokenId the ID of the Bear to claim earnings from
   * @param unstake whether or not to unstake the Bear
   * @return owed - the amount of $BULLIES earned
   */
  function _claimBearFromPack(uint256 tokenId, bool unstake) internal returns (uint256 owed) {
    require(deathRow.ownerOf(tokenId) == address(this), "Not on the clock");
    uint256 medals = _medalsForBear(tokenId);
    owed = calcRewardBear(tokenId);
    if (unstake) {
      totalBullsStaked -= medals; // Remove Medals from total staked
      deathRow.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // Send back Bear
      Stake memory lastStake = guards[medals][guards[medals].length - 1];
      guards[medals][guardIndices[tokenId]] = lastStake; // Shuffle last Bear to current position
      guardIndices[lastStake.tokenId] = guardIndices[tokenId];
      guards[medals].pop(); // Remove duplicate
      delete guardIndices[tokenId]; // Delete old mapping
    } 
    else {
      guards[medals][guardIndices[tokenId]] = Stake({
        owner: _msgSender(),
        tokenId: uint16(tokenId),
        value: uint80(bulliesPerMedal)
      }); // reset stake
      _deposits[_msgSender()].remove(tokenId);
    }
    emit BearClaimed(tokenId, owed, unstake);
  }

  /**
   * emergency unstake tokens
   * @param tokenIds the IDs of the tokens to claim earnings from
   */
  function rescue(uint256[] calldata tokenIds) external {
    require(rescueEnabled, "RESCUE DISABLED");
    uint256 tokenId;
    Stake memory stake;
    Stake memory lastStake;
    uint256 medals;
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      if (isBull(tokenId)) {
        stake = payroll[tokenId];
        require(stake.owner == _msgSender(), "You're going straight to jail");
        deathRow.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Bulls
        delete payroll[tokenId];
        totalBullsStaked -= 1;
        emit BullClaimed(tokenId, 0, true);
      } else {
        medals = _medalsForBear(tokenId);
        stake = guards[medals][guardIndices[tokenId]];
        require(stake.owner == _msgSender(), "You're going straight to jail");
        totalBullsStaked -= medals; // Remove Medals from total staked
        deathRow.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // Send back Bear
        lastStake = guards[medals][guards[medals].length - 1];
        guards[medals][guardIndices[tokenId]] = lastStake; // Shuffle last Bear to current position
        guardIndices[lastStake.tokenId] = guardIndices[tokenId];
        guards[medals].pop(); // Remove duplicate
        delete guardIndices[tokenId]; // Delete old mapping
        emit BearClaimed(tokenId, 0, true);
      }
    }
  }

  /** ACCOUNTING */

  /** 
   * add $BULLIES to claimable pot for the Pack
   * @param amount $BULLIES to add to the pot
   */
  function _payBearTax(uint256 amount) internal {
    if (totalBullsStaked == 0) { // if there's no staked wolves
      unaccountedRewards += amount; // keep track of $BULLIES due to wolves
      return;
    }
    // makes sure to include any unaccounted $BULLIES 
    bulliesPerMedal += (amount + unaccountedRewards) / totalBullsStaked;
    unaccountedRewards = 0;
  }

  /**
   * tracks $BULLIES earnings to ensure it stops once 2.4 billion is eclipsed
   */
  modifier _updateEarnings() {
    if (totalBulliesEarned < MAXIMUM_GLOBAL_BULLIES) {
      totalBulliesEarned += 
        (block.timestamp - lastClaimTimestamp)
        * totalBullsStaked
        * DAILY_BULLIES_RATE / 1 days; 
      lastClaimTimestamp = block.timestamp;
    }
    _;
  }

  /** ADMIN */

  /**
   * allows owner to enable "rescue mode"
   * simplifies accounting, prioritizes tokens out in emergency
   */
  function setRescueEnabled(bool _enabled) external onlyOwner {
    rescueEnabled = _enabled;
  }

  /**
   * enables owner to pause / unpause minting
   */
  function setPaused(bool _paused) external onlyOwner {
    if (_paused) _pause();
    else _unpause();
  }

  /** READ ONLY */

  /**
   * checks if a token is a Bulls
   * @param tokenId the ID of the token to check
   * @return bull - whether or not a token is a Bull
   */
  function isBull(uint256 tokenId) public view returns (bool bull) {
    (bull, , , , , , , , , ) = deathRow.tokenTraits(tokenId);
  }

  function _gangForBull(uint256 tokenId) internal view returns (uint8) {
    ( , , , , , , , , uint8 gang, ) = deathRow.tokenTraits(tokenId);
    return gang; // between 0 and 5
  }

  /**
   * gets the medals score for a Bear
   * @param tokenId the ID of the Bear to get the medals score for
   * @return the medals score of the Bear (0-5)
   */
  function _medalsForBear(uint256 tokenId) internal view returns (uint8) {
    ( , , , , , , , uint8 medals , ,) = deathRow.tokenTraits(tokenId);
    return medals; // between 1 and 5
  }

  /**
   * chooses a random Bear thief when a newly minted token is stolen
   * @param seed a random value to choose a Bear from
   * @return the owner of the randomly selected Bear thief
   */
  function randomBearOwner(uint256 seed) override external view returns (address) {
    if (totalBullsStaked == 0) return address(0x0);
    uint256 bucket = (seed & 0xFFFFFFFF) % totalBullsStaked; // choose a value from 0 to total medals staked
    uint256 cumulative;
    seed >>= 32;
    // loop through each bucket of Bears with the same medals score
    for (uint i = MAX_MEDALS - 3; i <= MAX_MEDALS; i++) {
      cumulative += guards[i].length * i;
      // if the value is not inside of that bucket, keep going
      if (bucket >= cumulative) continue;
      // get the address of a random Bear with that medals score
      return guards[i][seed % guards[i].length].owner;
    }
    return address(0x0);
  }

  /**
   * generates a pseudorandom number
   * @param seed a value ensure different outcomes for different sources in the same block
   * @return a pseudorandom value
   */
  function random(uint256 seed) internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(
      tx.origin,
      blockhash(block.number - 1),
      block.timestamp,
      seed
    )));
  }

  function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      require(from == address(0x0), "Cannot send tokens to Barn directly");
      return IERC721Receiver.onERC721Received.selector;
    }

  
}