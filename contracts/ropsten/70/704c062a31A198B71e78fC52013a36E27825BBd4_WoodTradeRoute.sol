// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Pirate.sol";
import "./WOOD.sol";

contract WoodTradeRoute is Ownable, IERC721Receiver, Pausable {
  
  // maximum alpha score for a Pirate
  uint8 public constant MAX_ALPHA = 8;

  // struct to store a stake's token, owner, and earning values
  struct Stake {
    uint16 tokenId;
    uint80 value;
    address owner;
  }

  event TokenStaked(address owner, uint256 tokenId, uint256 value);
  event MerchantClaimed(uint256 tokenId, uint256 earned, bool unstaked);
  event PirateClaimed(uint256 tokenId, uint256 earned, bool unstaked);

  // reference to the Pirate NFT contract
  Pirate pirate;
  // reference to the $WOOL contract for minting $WOOL earnings
  WOOD wood;

  // maps tokenId to stake
  mapping(uint256 => Stake) public tradeRoute; 
  // maps alpha to all Pirate stakes with that alpha
  mapping(uint256 => Stake[]) public fleet; 
  // tracks location of each Pirate in Fleet
  mapping(uint256 => uint256) public fleetIndices; 
  // total alpha scores staked
  uint256 public totalAlphaStaked = 0; 
  // any rewards distributed when no pirates are staked
  uint256 public unaccountedRewards = 0; 
  // amount of resources due for each alpha point staked
  uint256 public woodPerAlpha = 0; 

  // merchant earn 10000 resource per day
  uint256 public constant DAILY_WOOD_RATE = 10000 ether;
  // merchant must have 2 days worth of resource to unstake or else they're unprofitable
  uint256 public constant MINIMUM_TO_EXIT = 2 days;
  // pirates take a 20% tax on all resources claimed
  uint256 public constant WOOD_CLAIM_TAX_PERCENTAGE = 20;
  // there will only ever be (roughly) 2.4 billion resources earned through staking
  uint256 public constant MAXIMUM_GLOBAL_WOOD = 2400000000 ether;

  // amount of resources earned so far
  uint256 public totalWoodEarned;
  // number of Merchants staked in the trade route
  uint256 public totalMerchantsStaked;
  // the last time resource was claimed
  uint256 public lastClaimTimestamp;

  // emergency rescue to allow unstaking without any checks but without resources
  bool public rescueEnabled = false;

  /**
   * @param _pirate reference to the Pirate NFT contract
   * @param _wood reference to the resource token
   */
  constructor(address _pirate, address _wood) { 
    pirate = Pirate(_pirate);
    wood = WOOD(_wood);
  }

  /** STAKING */

  /**
   * adds Merchants and Pirates to the Trade Route and Fleet
   * @param account the address of the staker
   * @param tokenIds the IDs of the Merchants and Pirates to stake
   */
  function addManyToTradeRouteAndFleet(address account, uint16[] calldata tokenIds) external {
    require(account == _msgSender() || _msgSender() == address(pirate), "DONT GIVE YOUR TOKENS AWAY");
    for (uint i = 0; i < tokenIds.length; i++) {
      if (_msgSender() != address(pirate)) { // dont do this step if its a mint + stake
        require(pirate.ownerOf(tokenIds[i]) == _msgSender(), "AINT YO TOKEN");
        pirate.transferFrom(_msgSender(), address(this), tokenIds[i]);
      } else if (tokenIds[i] == 0) {
        continue; // there may be gaps in the array for stolen tokens
      }

      if (isMerchant(tokenIds[i])) 
        _addMerchantToTradeRoute(account, tokenIds[i]);
      else 
        _addPirateToFleet(account, tokenIds[i]);
    }
  }

  /**
   * adds a single Merchant to the TradeRoute
   * @param account the address of the staker
   * @param tokenId the ID of the Merchant to add to the Trade Route
   */
  function _addMerchantToTradeRoute(address account, uint256 tokenId) internal whenNotPaused _updateEarnings {
    tradeRoute[tokenId] = Stake({
      owner: account,
      tokenId: uint16(tokenId),
      value: uint80(block.timestamp)
    });
    totalMerchantsStaked += 1;
    emit TokenStaked(account, tokenId, block.timestamp);
  }

  /**
   * adds a single Pirate to the Fleet
   * @param account the address of the staker
   * @param tokenId the ID of the Pirate to add to the Fleet
   */
  function _addPirateToFleet(address account, uint256 tokenId) internal {
    uint256 alpha = _alphaForPirate(tokenId);
    totalAlphaStaked += alpha; // Portion of earnings ranges from 8 to 5
    fleetIndices[tokenId] = fleet[alpha].length; // Store the location of the pirate in the Fleet
    fleet[alpha].push(Stake({
      owner: account,
      tokenId: uint16(tokenId),
      value: uint80(woodPerAlpha)
    })); // Add the pirate to the Fleet
    emit TokenStaked(account, tokenId, woodPerAlpha);
  }

  /** CLAIMING / UNSTAKING */

  /**
   * realize resource earnings and optionally unstake tokens from the Route / Fleet
   * to unstake a Merchant it will require it has 2 days worth of resource unclaimed
   * @param tokenIds the IDs of the tokens to claim earnings from
   * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
   */
  function claimManyFromRouteAndFleet(uint16[] calldata tokenIds, bool unstake) external whenNotPaused _updateEarnings {
    uint256 owed = 0;
    for (uint i = 0; i < tokenIds.length; i++) {
      if (isMerchant(tokenIds[i]))
        owed += _claimMerchantFromRoute(tokenIds[i], unstake);
      else
        owed += _claimPirateFromFleet(tokenIds[i], unstake);
    }
    if (owed == 0) return;
    wood.mint(_msgSender(), owed);
  }

  /**
   * realize resource earnings for a single Merchant and optionally unstake it
   * if not unstaking, pay a 20% tax to the staked Pirates
   * if unstaking, there is a 50% chance all resource is stolen
   * @param tokenId the ID of the Merchant to claim earnings from
   * @param unstake whether or not to unstake the Merchant
   * @return owed - the amount of resource earned
   */
  function _claimMerchantFromRoute(uint256 tokenId, bool unstake) internal returns (uint256 owed) {
    Stake memory stake = tradeRoute[tokenId];
    require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
    require(!(unstake && block.timestamp - stake.value < MINIMUM_TO_EXIT), "NOT PROFITABLE WITHOUT 2 DAYS RESOURCES");
    if (totalWoodEarned < MAXIMUM_GLOBAL_WOOD) {
      owed = (block.timestamp - stake.value) * DAILY_WOOD_RATE / 1 days;
    } else if (stake.value > lastClaimTimestamp) {
      owed = 0; // resource production stopped already
    } else {
      owed = (lastClaimTimestamp - stake.value) * DAILY_WOOD_RATE / 1 days; // stop earning additional resource if it's all been earned
    }
    if (unstake) {
      if (random(tokenId) & 1 == 1) { // 50% chance of all resource stolen
        _payPirateTax(owed);
        owed = 0;
      }
      pirate.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Merchant
      delete tradeRoute[tokenId];
      totalMerchantsStaked -= 1;
    } else {
      _payPirateTax(owed * WOOD_CLAIM_TAX_PERCENTAGE / 100); // percentage tax to staked pirates
      owed = owed * (100 - WOOD_CLAIM_TAX_PERCENTAGE) / 100; // remainder goes to Merchants owner
      tradeRoute[tokenId] = Stake({
        owner: _msgSender(),
        tokenId: uint16(tokenId),
        value: uint80(block.timestamp)
      }); // reset stake
    }
    emit MerchantClaimed(tokenId, owed, unstake);
  }

  /**
   * realize resource earnings for a single Pirate and optionally unstake it
   * Pirates earn $resource proportional to their Alpha rank
   * @param tokenId the ID of the Pirate to claim earnings from
   * @param unstake whether or not to unstake the Pirate
   * @return owed - the amount of resource earned
   */
  function _claimPirateFromFleet(uint256 tokenId, bool unstake) internal returns (uint256 owed) {
    require(pirate.ownerOf(tokenId) == address(this), "AINT A PART OF THE FLEET");
    uint256 alpha = _alphaForPirate(tokenId);
    Stake memory stake = fleet[alpha][fleetIndices[tokenId]];
    require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
    owed = (alpha) * (woodPerAlpha - stake.value); // Calculate portion of tokens based on Alpha
    if (unstake) {
      totalAlphaStaked -= alpha; // Remove Alpha from total staked
      pirate.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // Send back Pirate
      Stake memory lastStake = fleet[alpha][fleet[alpha].length - 1];
      fleet[alpha][fleetIndices[tokenId]] = lastStake; // Shuffle last Pirate to current position
      fleetIndices[lastStake.tokenId] = fleetIndices[tokenId];
      fleet[alpha].pop(); // Remove duplicate
      delete fleetIndices[tokenId]; // Delete old mapping
    } else {
      fleet[alpha][fleetIndices[tokenId]] = Stake({
        owner: _msgSender(),
        tokenId: uint16(tokenId),
        value: uint80(woodPerAlpha)
      }); // reset stake
    }
    emit PirateClaimed(tokenId, owed, unstake);
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
    uint256 alpha;
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      if (isMerchant(tokenId)) {
        stake = tradeRoute[tokenId];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        pirate.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Merchant
        delete tradeRoute[tokenId];
        totalMerchantsStaked -= 1;
        emit MerchantClaimed(tokenId, 0, true);
      } else {
        alpha = _alphaForPirate(tokenId);
        stake = fleet[alpha][fleetIndices[tokenId]];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        totalAlphaStaked -= alpha; // Remove Alpha from total staked
        pirate.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // Send back Pirate
        lastStake = fleet[alpha][fleet[alpha].length - 1];
        fleet[alpha][fleetIndices[tokenId]] = lastStake; // Shuffle last Pirate to current position
        fleetIndices[lastStake.tokenId] = fleetIndices[tokenId];
        fleet[alpha].pop(); // Remove duplicate
        delete fleetIndices[tokenId]; // Delete old mapping
        emit PirateClaimed(tokenId, 0, true);
      }
    }
  }

  /** ACCOUNTING */

  /** 
   * add resource to claimable pot for the Fleet
   * @param amount resource to add to the pot
   */
  function _payPirateTax(uint256 amount) internal {
    if (totalAlphaStaked == 0) { // if there's no staked pirates
      unaccountedRewards += amount; // keep track of resouce due to pirates
      return;
    }
    // makes sure to include any unaccounted resource 
    woodPerAlpha += (amount + unaccountedRewards) / totalAlphaStaked;
    unaccountedRewards = 0;
  }

  /**
   * tracks $resource earnings to ensure it stops once 2.4 billion is eclipsed
   */
  modifier _updateEarnings() {
    if (totalWoodEarned < MAXIMUM_GLOBAL_WOOD) {
      totalWoodEarned += 
        (block.timestamp - lastClaimTimestamp)
        * totalMerchantsStaked
        * DAILY_WOOD_RATE / 1 days; 
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
   * checks if a token is a Merchant
   * @param tokenId the ID of the token to check
   * @return merchant - whether or not a token is a Merchant
   */
  function isMerchant(uint256 tokenId) public view returns (bool merchant) {
    (merchant, , , , , , , , , ) = pirate.tokenTraits(tokenId);
  }

  /**
   * gets the alpha score for a Pirate
   * @param tokenId the ID of the Pirate to get the alpha score for
   * @return the alpha score of the Pirate (5-8)
   */
  function _alphaForPirate(uint256 tokenId) internal view returns (uint8) {
    ( , , , , , , , , , uint8 alphaIndex) = pirate.tokenTraits(tokenId);
    return MAX_ALPHA - alphaIndex; // alpha index is 0-3
  }

  /**
   * chooses a random Pirate thief when a newly minted token is stolen
   * @param seed a random value to choose a Pirate from
   * @return the owner of the randomly selected Pirate thief
   */
  function randomPirateOwner(uint256 seed) external view returns (address) {
    if (totalAlphaStaked == 0) return address(0x0);
    uint256 bucket = (seed & 0xFFFFFFFF) % totalAlphaStaked; // choose a value from 0 to total alpha staked
    uint256 cumulative;
    seed >>= 32;
    // loop through each bucket of Wolves with the same alpha score
    for (uint i = MAX_ALPHA - 3; i <= MAX_ALPHA; i++) {
      cumulative += fleet[i].length * i;
      // if the value is not inside of that bucket, keep going
      if (bucket >= cumulative) continue;
      // get the address of a random Pirate with that alpha score
      return fleet[i][seed % fleet[i].length].owner;
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
      require(from == address(0x0), "Cannot send tokens to Trade Route directly");
      return IERC721Receiver.onERC721Received.selector;
    }

  
}