// SPDX-License-Identifier: MIT LICENSE

// Needs to update to 0.8.0
pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import './CryptoBees.sol';
import './Honey.sol';

contract Hive is Ownable, IERC721Receiver, Pausable {
  // struct to store a stake's token, owner, and earning values

  struct Stake {
    uint16 tokenId;
    uint80 value;
    address owner;
  }

  struct BeeHive {
    uint80 timestamp;
    uint80 subtract;
    uint80 occupancy;
    mapping(uint256 => Stake) bees;
  }

  event TokenStaked(address indexed owner, uint256 hiveId, uint256 tokenId, uint256 value);
  event TokenClaimed(uint256 tokenId, uint256 earned, uint256 newHiveId);

  // reference to the Bees NFT contract
  CryptoBees bees = CryptoBees(0x5D698C06bC903769B3A661FF11144bCBEc4A43CB);
  // reference to the $HONEY contract for minting $HONEY earnings
  Honey honey = Honey(0x3b6F57900FAb6f0EC8D3d1d3538159eE96B5c105);

  // maps tokenId to hives
  mapping(uint256 => BeeHive) public hives;
  // mapping(address => uint256[]) public owners;
  // maps alpha to all Wolf stakes with that alpha
  // any rewards distributed when no wolves are staked
  // uint256 public unaccountedRewards = 0;
  // amount of $HONEY due for each alpha point staked
  // uint256 public woolPerAlpha = 0;

  // sheep earn 200 $HONEY per day
  uint256 public constant DAILY_HONEY_RATE = 200 ether;
  // sheep must have 2 days worth of $HONEY to unstake or else it's too cold
  uint256 public constant MINIMUM_TO_EXIT = 1 days;
  // there will only ever be (roughly) 2.4 billion $HONEY earned through staking
  uint256 public constant MAXIMUM_GLOBAL_HONEY = 2400000000 ether;

  // amount of $HONEY earned so far
  uint256 public totalHoneyEarned;
  // number of Bees staked in the Barn
  uint256 public totalBeesStaked;
  // the last time $HONEY was claimed
  uint256 public lastClaimTimestamp;

  // emergency rescue to allow unstaking without any checks but without $HONEY
  bool public rescueEnabled = false;

  /**
   */
  constructor() {}

  /** STAKING */

  /**
   * adds Bees to the Hive
   * @param account the address of the staker
   * @param tokenIds the IDs of the Bees
   * @param hiveIds the IDs of the Hives
   */
  function addManyToHive(
    address account,
    uint16[] calldata tokenIds,
    uint16[] calldata hiveIds
  ) external {
    require(account == _msgSender() || _msgSender() == address(bees), 'DONT GIVE YOUR TOKENS AWAY');
    require(tokenIds.length == hiveIds.length, 'THE ARGUMENTS LENGTHS DO NOT MATCH');
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (_msgSender() != address(bees)) {
        // dont do this step if its a mint + stake
        require(bees.ownerOf(tokenIds[i]) == _msgSender(), 'AINT YO TOKEN');
        bees.transferFrom(_msgSender(), address(this), tokenIds[i]);
      } else if (tokenIds[i] == 0) {
        continue; // there may be gaps in the array for stolen tokens
      }

      _addBeeToHive(account, tokenIds[i], hiveIds[i]);
    }
  }

  /**
   * adds a single Bee to a specific Hive
   * @param account the address of the staker
   * @param tokenId the ID of the Bee to add
   * @param hiveId the ID of the Hive
   */
  function _addBeeToHive(
    address account,
    uint256 tokenId,
    uint256 hiveId
  ) internal whenNotPaused _updateEarnings {
    hives[hiveId].bees[tokenId] = Stake({ owner: account, tokenId: uint16(tokenId), value: uint80(block.timestamp) });
    totalBeesStaked += 1;
    emit TokenStaked(account, hiveId, tokenId, block.timestamp);
  }

  /** CLAIMING / UNSTAKING */

  /**
   * change hive or unstake and realize $HONEY earnings
   * it requires it has 1 day worth of $HONEY unclaimed
   * @param tokenIds the IDs of the tokens to claim earnings from
   * @param hiveIds the IDs of the Hives for each Bee
   * @param newHiveIds the IDs of new Hives (or to unstake if it's -1)
   */
  function claimManyFromHive(
    uint16[] calldata tokenIds,
    uint16[] calldata hiveIds,
    uint16[] calldata newHiveIds
  ) external whenNotPaused _updateEarnings {
    require(tokenIds.length == hiveIds.length && tokenIds.length == newHiveIds.length, 'THE ARGUMENTS LENGTHS DO NOT MATCH');
    uint256 owed = 0;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      owed += _claimBeeFromHive(tokenIds[i], hiveIds[i], newHiveIds[i]);
    }
    if (owed == 0) return;
    honey.mint(_msgSender(), owed);
  }

  /**
   * change hive or unstake and realize $HONEY earnings
   * @param tokenId the ID of the Bee to claim earnings from
   * @param hiveId the ID of the Hive where the Bee is
   * @param newHiveId the ID of the Hive where the Bee want to go (-1 for unstake)
   * @return owed - the amount of $HONEY earned
   */
  function _claimBeeFromHive(
    uint256 tokenId,
    uint256 hiveId,
    uint256 newHiveId
  ) internal returns (uint256 owed) {
    Stake memory stake = hives[hiveId].bees[tokenId];
    require(stake.owner == _msgSender(), 'SWIPER, NO SWIPING');
    // require(!(block.timestamp - stake.value < MINIMUM_TO_EXIT), 'YOU NEED MORE HONEY TO GET OUT OF THE HIVE');
    if (totalHoneyEarned < MAXIMUM_GLOBAL_HONEY) {
      owed = ((block.timestamp - stake.value) * DAILY_HONEY_RATE) / 1 days;
    } else if (stake.value > lastClaimTimestamp) {
      owed = 0; // $HONEY production stopped already
    } else {
      owed = ((lastClaimTimestamp - stake.value) * DAILY_HONEY_RATE) / 1 days; // stop earning additional $HONEY if it's all been earned
    }
    if (newHiveId == 0) {
      bees.safeTransferFrom(address(this), _msgSender(), tokenId, ''); // send back Sheep
      delete hives[hiveId].bees[tokenId];
      totalBeesStaked -= 1;
    } else {
      delete hives[hiveId].bees[tokenId];
      hives[newHiveId].bees[tokenId] = Stake({ owner: _msgSender(), tokenId: uint16(tokenId), value: uint80(block.timestamp) }); // reset stake
    }
    emit TokenClaimed(tokenId, owed, newHiveId);
  }

  function manyBearsAttack(uint256 tokenId) external whenNotPaused _updateEarnings {
    require(bees.ownerOf(tokenId) == _msgSender(), 'YOU ARE NOT THE OWNER');
    require(bees.getTokenNumType(tokenId) == 1, 'TOKEN NOT A BEAR');
    honey.mint(_msgSender(), 10000);
  }

  /**
   * emergency unstake tokens
   * @param tokenIds the IDs of the tokens to claim earnings from
   */
  // function rescue(uint256[] calldata tokenIds) external {
  //   require(rescueEnabled, 'RESCUE DISABLED');
  //   uint256 tokenId;
  //   Stake memory stake;
  //   Stake memory lastStake;
  //   uint256 alpha;
  //   for (uint256 i = 0; i < tokenIds.length; i++) {
  //     tokenId = tokenIds[i];
  //     if (isSheep(tokenId)) {
  //       stake = hives[tokenId];
  //       require(stake.owner == _msgSender(), 'SWIPER, NO SWIPING');
  //       woolf.safeTransferFrom(address(this), _msgSender(), tokenId, ''); // send back Sheep
  //       delete hives[tokenId];
  //       totalSheepStaked -= 1;
  //       emit SheepClaimed(tokenId, 0, true);
  //     } else {
  //       alpha = _alphaForWolf(tokenId);
  //       stake = pack[alpha][packIndices[tokenId]];
  //       require(stake.owner == _msgSender(), 'SWIPER, NO SWIPING');
  //       totalAlphaStaked -= alpha; // Remove Alpha from total staked
  //       woolf.safeTransferFrom(address(this), _msgSender(), tokenId, ''); // Send back Wolf
  //       lastStake = pack[alpha][pack[alpha].length - 1];
  //       pack[alpha][packIndices[tokenId]] = lastStake; // Shuffle last Wolf to current position
  //       packIndices[lastStake.tokenId] = packIndices[tokenId];
  //       pack[alpha].pop(); // Remove duplicate
  //       delete packIndices[tokenId]; // Delete old mapping
  //       emit WolfClaimed(tokenId, 0, true);
  //     }
  //   }
  // }

  /** ACCOUNTING */

  /**
   * add $HONEY to claimable pot for the Pack
   * @param amount $HONEY to add to the pot
   */
  // function _payWolfTax(uint256 amount) internal {
  //   if (totalAlphaStaked == 0) {
  //     // if there's no staked wolves
  //     unaccountedRewards += amount; // keep track of $HONEY due to wolves
  //     return;
  //   }
  //   // makes sure to include any unaccounted $HONEY
  //   woolPerAlpha += (amount + unaccountedRewards) / totalAlphaStaked;
  //   unaccountedRewards = 0;
  // }

  /**
   * tracks $HONEY earnings to ensure it stops once 2.4 billion is eclipsed
   */
  modifier _updateEarnings() {
    if (totalHoneyEarned < MAXIMUM_GLOBAL_HONEY) {
      totalHoneyEarned += ((block.timestamp - lastClaimTimestamp) * totalBeesStaked * DAILY_HONEY_RATE) / 1 days;
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

  function getInfoOnBee(uint256 tokenId, uint256 hiveId) public view returns (Stake memory) {
    return hives[hiveId].bees[tokenId];
  }

  /**
   * checks if a token is a Sheep
   * @param tokenId the ID of the token to check
   * @return sheep - whether or not a token is a Sheep
   */
  // function isSheep(uint256 tokenId) public view returns (bool sheep) {
  //   (sheep, , , , , , , , , ) = woolf.tokenTraits(tokenId);
  // }

  /**
   * gets the alpha score for a Wolf
   * @param tokenId the ID of the Wolf to get the alpha score for
   * @return the alpha score of the Wolf (5-8)
   */
  // function _alphaForWolf(uint256 tokenId) internal view returns (uint8) {
  //   (, , , , , , , , , uint8 alphaIndex) = woolf.tokenTraits(tokenId);
  //   return MAX_ALPHA - alphaIndex; // alpha index is 0-3
  // }

  // /**
  //  * chooses a random Wolf thief when a newly minted token is stolen
  //  * @param seed a random value to choose a Wolf from
  //  * @return the owner of the randomly selected Wolf thief
  //  */
  // function randomWolfOwner(uint256 seed) external view returns (address) {
  //   if (totalAlphaStaked == 0) return address(0x0);
  //   uint256 bucket = (seed & 0xFFFFFFFF) % totalAlphaStaked; // choose a value from 0 to total alpha staked
  //   uint256 cumulative;
  //   seed >>= 32;
  //   // loop through each bucket of Wolves with the same alpha score
  //   for (uint256 i = MAX_ALPHA - 3; i <= MAX_ALPHA; i++) {
  //     cumulative += pack[i].length * i;
  //     // if the value is not inside of that bucket, keep going
  //     if (bucket >= cumulative) continue;
  //     // get the address of a random Wolf with that alpha score
  //     return pack[i][seed % pack[i].length].owner;
  //   }
  //   return address(0x0);
  // }

  /**
   * generates a pseudorandom number
   * @param seed a value ensure different outcomes for different sources in the same block
   * @return a pseudorandom value
   */
  function random(uint256 seed) internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(tx.origin, blockhash(block.number - 1), block.timestamp, seed)));
  }

  // function getStakedTokenIds(address _address) public view returns (uint256[] memory) {
  //   return owners[_address];
  // }

  function onERC721Received(
    address,
    address from,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    require(from == address(0x0), 'Cannot send tokens to Barn directly');
    return IERC721Receiver.onERC721Received.selector;
  }
}