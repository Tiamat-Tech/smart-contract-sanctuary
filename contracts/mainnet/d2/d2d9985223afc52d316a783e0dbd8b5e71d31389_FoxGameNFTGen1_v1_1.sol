/*
███████╗ ██████╗ ██╗  ██╗     ██████╗  █████╗ ███╗   ███╗███████╗
██╔════╝██╔═══██╗╚██╗██╔╝    ██╔════╝ ██╔══██╗████╗ ████║██╔════╝
█████╗  ██║   ██║ ╚███╔╝     ██║  ███╗███████║██╔████╔██║█████╗  
██╔══╝  ██║   ██║ ██╔██╗     ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  
██║     ╚██████╔╝██╔╝ ██╗    ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗
╚═╝      ╚═════╝ ╚═╝  ╚═╝     ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "./IFoxGameNFTTraits.sol";
import "./IFoxGameCarrot.sol";
import "./IFoxGameCrown.sol";
import "./IFoxGameNFT.sol";
import "./IFoxGame.sol";

contract FoxGameNFTGen1_v1_1 is IFoxGameNFT, ERC721EnumerableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using ECDSAUpgradeable for bytes32; // signature verification helpers

  // Presale status
  bool public saleActive;

  // Mumber of players minted
  uint16 public minted;

  // External contracts
  IFoxGameCarrot private foxCarrot;
  IFoxGameNFTTraits private foxTraits;
  IFoxGame private foxGame;

  // Maximum players in the game
  uint16 public constant MAX_TOKENS = 50000;

  // Number of GEN 0 tokens
  uint16 public constant MAX_GEN0_TOKENS = 10000;

  // Rarity trait probabilities
  uint8[][29] private rarities;
  uint8[][29] private aliases;

  // Mapping of token ID to player traits
  mapping(uint16 => Traits) private tokenTraits;

  // Store previous trait combinations to prevent duplicates
  mapping(uint256 => bool) private knownCombinations;

  // Store origin seeds for each token
  mapping(uint32 => uint256) private tokenSeeds;

  // Events
  event SaleActive(bool active);
  event Mint(string kind, address owner, uint16 tokenId);
  event MintStolen(address thief, address victim, string kind, uint16 tokenId);

  // Mapping of traits to metadata display names
  string[3] private _types;

  // Store the latest block number to setup future calls requiring randomness
  // Address => Coin => Block Number
  mapping(address => mapping(IFoxGameNFT.Coin => uint32)) private _lastMintBlock;

  // Crown utility token
  IFoxGameCrown private foxCrown;

  // Event to handle mint failures
  event MintFailure(address account);

  // Init contract upgradability (only called once)
  function initialize(address carrot, address game, address traits) public initializer {
    __ERC721_init("FoxGame", "FOX");
    __ERC721Enumerable_init();
    __Ownable_init();
    __ReentrancyGuard_init();

    foxCarrot = IFoxGameCarrot(carrot);
    foxGame = IFoxGame(game);
    foxTraits = IFoxGameNFTTraits(traits);

    // Gen 1 starting token ID
    minted = MAX_GEN0_TOKENS;

    // Define token type names
    _types = [ "Rabbit", "Fox", "Hunter" ];

    // Precomputed rarity probabilities on chain.
    // (via walker's alias algorithm)

    // RABBIT

    // Fur
    rarities[0] = [ 153, 153, 255, 102, 77, 230 ];
    aliases[0] = [ 2, 2, 0, 2, 3, 3 ];
    // Paws
    rarities[1] = [ 61, 184, 122, 122, 61, 255, 204, 122, 224, 255, 214, 184, 235, 61, 184, 184, 184, 122, 122, 184, 153, 245, 143, 224 ];
    aliases[1] = [ 6, 8, 8, 9, 10, 0, 5, 15, 6, 8, 9, 15, 10, 20, 20, 12, 21, 22, 23, 23, 15, 20, 21, 22 ];
    // Mouth
    rarities[2] = [ 191, 77, 191, 255, 38, 115, 204, 153, 191, 38, 64, 115, 77, 115, 128 ];
    aliases[2] = [ 3, 3, 3, 0, 7, 7, 3, 6, 7, 10, 8, 13, 14, 10, 13 ];
    // Nose
    rarities[3] = [ 255, 242, 153, 204, 115, 230, 230, 115, 115 ];
    aliases[3] = [ 0, 0, 1, 2, 0, 0, 0, 2, 3 ];
    // Eyes
    rarities[4] = [ 77, 255, 128, 77, 153, 153, 153, 77, 153, 230, 77, 77, 77, 204, 179, 230, 77, 179, 128, 179, 153, 230, 77, 77, 102, 77, 153, 153, 204, 77 ];
    aliases[4] = [ 3, 0, 1, 2, 13, 13, 13, 13, 14, 14, 18, 19, 20, 3, 13, 20, 24, 14, 17, 18, 19, 20, 25, 25, 21, 24, 25, 26, 26, 28 ];
    // Ears
    rarities[5] = [ 41, 61, 102, 204, 255, 102, 204, 204 ];
    aliases[5] = [ 5, 5, 5, 5, 0, 4, 5, 5 ];
    // Head
    rarities[6] = [ 87, 255, 130, 245, 173, 173, 191, 87, 176, 128, 217, 43, 173, 217, 92, 217, 43 ];
    aliases[6] = [ 1, 0, 3, 1, 6, 6, 3, 9, 6, 8, 9, 9, 9, 9, 9, 9, 14 ];

    // FOX

    // Tail
    rarities[7] = [ 255, 153, 204, 102 ];
    aliases[7] = [ 0, 0, 0, 1 ];
    // Fur
    rarities[8] = [ 255, 204, 153, 153 ];
    aliases[8] = [ 0, 0, 1, 1 ];
    // Feet
    rarities[9] = [ 255, 255, 229, 204, 229, 204, 179, 255, 255, 128 ];
    aliases[9] = [ 0, 0, 1, 2, 3, 2, 3, 0, 0, 4 ];
    //  Neck
    rarities[10] = [ 255, 204, 204, 204, 127, 102, 51, 255, 255, 26 ];
    aliases[10] = [ 0, 0, 1, 0, 2, 0, 1, 0, 0, 4 ];
    // Mouth
    rarities[11] = [ 255, 102, 255, 255, 204, 153, 102, 255, 51, 51, 255, 204, 255, 204, 153, 204, 153, 51, 255, 51 ];
    aliases[11] = [ 0, 2, 0, 2, 3, 2, 4, 6, 6, 6, 0, 7, 11, 12, 13, 7, 11, 13, 0, 14 ];
    // Eyes
    rarities[12] = [ 56, 255, 179, 153, 158, 112, 133, 112, 112, 56, 250, 224, 199, 122, 240, 214, 189, 112, 112, 163, 112, 138 ];
    aliases[12] = [ 1, 0, 1, 2, 3, 1, 4, 3, 6, 12, 6, 10, 11, 12, 13, 14, 15, 12, 13, 16, 21, 19 ];
    // Cunning Score
    rarities[13] = [ 255, 153, 204, 102 ];
    aliases[13] = [ 0, 0, 0, 1 ];

    // HUNTER

    // Clothes
    rarities[14] = [ 128, 255, 128, 64, 255 ];
    aliases[14] = [ 2, 0, 1, 2, 0 ];
    // Weapon
    rarities[15] = [ 255, 153, 204, 102 ];
    aliases[15] = [ 0, 0, 0, 1 ];
    // Neck
    rarities[16] = [ 102, 255, 26, 153, 255 ];
    aliases[16] = [ 1, 0, 3, 1, 0 ];
    // Mouth
    rarities[17] = [ 255, 229, 179, 179, 89, 179, 217 ];
    aliases[17] = [ 0, 0, 0, 6, 6, 6, 1 ];
    // Eyes
    rarities[18] = [ 191, 255, 38, 77, 191, 77, 217, 38, 153, 191, 77, 191, 204, 77, 77 ];
    aliases[18] = [ 1, 0, 4, 4, 1, 4, 5, 5, 6, 5, 5, 6, 8, 8, 12 ];
    // Hat
    rarities[19] = [ 191, 38, 89, 255, 191 ];
    aliases[19] = [ 3, 4, 4, 0, 3 ];
    // Marksman Score
    rarities[20] = [ 255, 153, 204, 102 ];
    aliases[20] = [ 0, 0, 0, 1 ];
  }

  /**
   * Update the utility token contract address.
   */
  function setCrownContract(address _address) external onlyOwner {
    foxCrown = IFoxGameCrown(_address);
  }

  /**
   * Helper method to fetch rotating entropy used to generate random seeds off-chain.
   */
  function getEntropy(address recipient, IFoxGameNFT.Coin token) external view returns (uint256) {
    require(tx.origin == msg.sender, "eos only");

    // Last mint block (defaults to zero the first time)
    return _lastMintBlock[recipient][token];
  }

  /**
   * Upload rarity propbabilties. Only used in emergencies.
   * @param traitTypeId trait name id (0 corresponds to "fur")
   * @param _rarities walker rarity probailities
   * @param _aliases walker aliases index
   */
  function uploadTraits(uint8 traitTypeId, uint8[] calldata _rarities, uint8[] calldata _aliases) external onlyOwner {
    rarities[traitTypeId] = _rarities;
    aliases[traitTypeId] = _aliases;
  }

  /**
   * Enable Sale.
   */
  function toggleSale() external onlyOwner {
    saleActive = !saleActive;
    emit SaleActive(saleActive);
  }

  /**
   * Update the utility token contract address.
   */
  function setCarrotContract(address _address) external onlyOwner {
    foxCarrot = IFoxGameCarrot(_address);
  }

  /**
   * Update the staking contract address.
   */
  function setGameContract(address _address) external onlyOwner {
    foxGame = IFoxGame(_address);
  }

  /**
   * Update the ERC-721 trait contract address.
   */
  function setTraitsContract(address _address) external onlyOwner {
    foxTraits = IFoxGameNFTTraits(_address);
  }

  /**
   * Expose traits to trait contract.
   */
  function getTraits(uint16 tokenId) external view override returns (Traits memory) {
    return tokenTraits[tokenId];
  }

  /**
   * Expose maximum GEN 0 tokens.
   */
  function getMaxGEN0Players() external pure override returns (uint16) {
    return MAX_GEN0_TOKENS;
  }

  /**
   * Mint your players.
   * @param amount number of tokens to mint
   * @param stake mint directly to staking
   * @param token token to mint with (0 = CARRROT, 1 = CROWN)
   * @param blocknum block number used to generate randomness
   * @param originSeed account seed
   * @param sig signature 
   */
  function mint(uint32 amount, bool stake, IFoxGameNFT.Coin token, uint32 blocknum, uint256 originSeed, bytes calldata sig) external payable nonReentrant {
    require(blocknum == _lastMintBlock[msg.sender][token], "seed block did not match");
    require(tx.origin == msg.sender, "eos only");
    require(saleActive, "minting is not active");
    require(minted + amount <= MAX_TOKENS, "minted out");
    require(amount > 0 && amount <= 20, "invalid mint amount");
    require(msg.value == 0, "only carrots required");
    require(token == IFoxGameNFT.Coin.CARROT || token == IFoxGameNFT.Coin.CROWN, "unknown token");
    require(foxGame.isValidMintSignature(msg.sender, uint8(token), blocknum, originSeed, sig), "invalid signature");

    // CARROT mints are only allowed when holding a Barrel
    bool ownsBarrel = foxGame.ownsBarrel(msg.sender);
    require(token != IFoxGameNFT.Coin.CARROT || ownsBarrel, "CARROT minting requires a barrel");

    // Update block for next mint
    _lastMintBlock[msg.sender][token] = uint32(block.number);

    // Determine if user is facing greater risk of losing mint
    bool elevatedRisk = foxGame.getCorruptionEnabled() && !ownsBarrel;

    // Mint tokens
    Kind kind;
    uint16[] memory tokenIdsToStake = stake ? new uint16[](amount) : new uint16[](0);
    uint256 mintCost;
    uint256 seed;
    string memory kindLabel;
    for (uint32 i; i < amount; i++) {
      minted++;
      seed = _reseedWithIndex(originSeed, minted + i);
      mintCost += getMintCost(token, minted);
      // Handle failure to mint
      if (token == IFoxGameNFT.Coin.CARROT && (seed >> 224) % 10 != 0) {
        minted--; // dial back token id
        emit MintFailure(msg.sender);
        continue;
      }
      kind = _generateAndStoreTraits(minted, seed, 0).kind;
      kindLabel = _types[uint8(kind)];
      address recipient = _selectRecipient(seed, elevatedRisk);
      if (recipient != msg.sender) {     // Stolen
        _safeMint(recipient, minted);
        emit MintStolen(recipient, msg.sender, kindLabel, minted);
      } else {
        if (stake) {                     // Staked
          tokenIdsToStake[i] = minted;
          _safeMint(address(foxGame), minted);
        } else {                         // Mint
          _safeMint(msg.sender, minted);
        }
        emit Mint(kindLabel, msg.sender, minted);
      }
    }
    // Burn
    if (token == IFoxGameNFT.Coin.CARROT) {
      foxCarrot.burn(msg.sender, mintCost);
    } else {
      foxCrown.burn(msg.sender, mintCost);
    }
    // Stake
    if (stake) {
      foxGame.stakeTokens(msg.sender, tokenIdsToStake);
    }
  }

  /**
   * Calculate the foxCarrot cost:
   * - the first 20% are 20000 $CROWN / 120000 $CARROT
   * - the next 40% are 40000 $CROWN / 140000 $CARROT
   * - the final 20% are 80000 $CROWN / 180000 $CARROT
   * @param token utility token to pay for mint
   * @param tokenId the ID to check the cost of to mint
   * @return the cost of the given token ID
   */
  function getMintCost(IFoxGameNFT.Coin token, uint16 tokenId) public pure returns (uint256) {
    if (token == IFoxGameNFT.Coin.CARROT) {
      if (tokenId <= 20000) return 120000 ether;
      if (tokenId <= 40000) return 140000 ether;
      return 180000 ether;
    } else { // CROWN
      if (tokenId <= 20000) return 20000 ether;
      if (tokenId <= 40000) return 40000 ether;
      return 80000 ether;
    }
  }

  /**
   * Generate and store player traits. Recursively called to ensure uniqueness.
   * Give users 3 attempts, bit shifting the seed each time (uses 5 bytes of entropy before failing)
   * @param tokenId id of the token to generate traits
   * @param seed random 256 bit seed to derive traits
   * @return t player trait struct
   */
  function _generateAndStoreTraits(uint16 tokenId, uint256 seed, uint8 attempt) internal returns (Traits memory t) {
    require(attempt < 6, "unable to generate unique traits");
    t = _selectTraits(seed);
    if (!knownCombinations[_structToHash(t)]) {
      tokenTraits[tokenId] = t;
      knownCombinations[_structToHash(t)] = true;
      return t;
    }
    return _generateAndStoreTraits(tokenId, seed >> attempt, attempt + 1);
  }

  /**
   * uses A.J. Walker's Alias algorithm for O(1) rarity table lookup
   * ensuring O(1) instead of O(n) reduces mint cost by more than 50%
   * probability & alias tables are generated off-chain beforehand
   * @param seed portion of the 256 bit seed to remove trait correlation
   * @param traitType the trait type to select a trait for 
   * @return the ID of the randomly selected trait
   */
  function _selectTrait(uint16 seed, uint8 traitType) internal view returns (uint8) {
    uint8 trait = uint8(seed) % uint8(rarities[traitType].length);
    if (seed >> 8 < rarities[traitType][trait]) return trait;
    return aliases[traitType][trait];
  }

  /**
   * the first 20% (ETH purchases) go to the minter
   * the remaining 80% have a 10% chance to be given to a random staked fox
   * @param seed a random value to select a recipient from
   * @param elevatedRisk true if the user is at higher risk of losing their mint
   * @return the address of the recipient (either the minter or the fox thief's owner)
   */
  function _selectRecipient(uint256 seed, bool elevatedRisk) internal view returns (address) {
    if (((seed >> 245) % (elevatedRisk ? 4 : 10)) != 0) {
      return msg.sender; // top 10 bits haven't been used
    }
    // 144 bits reserved for trait selection
    address thief = foxGame.randomFoxOwner(seed >> 144);
    if (thief == address(0x0)) {
      return msg.sender;
    }
    return thief;
  }

  /**
   * selects the species and all of its traits based on the seed value
   * @param seed a pseudorandom 256 bit number to derive traits from
   * @return t struct of randomly selected traits
   */
  function _selectTraits(uint256 seed) internal view returns (Traits memory t) {
    uint mod = (seed & 0xFFFF) % 50;
    t.kind = Kind(mod == 0 ? 2 : mod < 5 ? 1 : 0);
    // Use 128 bytes of seed entropy to define traits.
    uint8 offset = uint8(t.kind) * 7;                                           // RABBIT FOX     HUNTER
    seed >>= 16; t.traits[0] = _selectTrait(uint16(seed & 0xFFFF), 0 + offset); // Fur    Tail    Clothes
    seed >>= 16; t.traits[1] = _selectTrait(uint16(seed & 0xFFFF), 1 + offset); // Head   Fur     Weapon
    seed >>= 16; t.traits[2] = _selectTrait(uint16(seed & 0xFFFF), 2 + offset); // Ears   Eyes    Neck
    seed >>= 16; t.traits[3] = _selectTrait(uint16(seed & 0xFFFF), 3 + offset); // Eyes   Mouth   Mouth
    seed >>= 16; t.traits[4] = _selectTrait(uint16(seed & 0xFFFF), 4 + offset); // Nose   Neck    Eyes
    seed >>= 16; t.traits[5] = _selectTrait(uint16(seed & 0xFFFF), 5 + offset); // Mouth  Feet    Hat
    seed >>= 16; t.traits[6] = _selectTrait(uint16(seed & 0xFFFF), 6 + offset); // Paws   Cunning Marksman
    if (t.kind == IFoxGameNFT.Kind.FOX) {
      t.advantage = t.traits[6] = t.traits[0];
    } else if (t.kind == IFoxGameNFT.Kind.HUNTER) {
      t.advantage = t.traits[6] = t.traits[1];
    }
  }

  /**
   * converts a struct to a 256 bit hash to check for uniqueness
   * @param t the struct to pack into a hash
   * @return the 256 bit hash of the struct
   */
  function _structToHash(Traits memory t) internal pure returns (uint256) {
    return uint256(bytes32(
      abi.encodePacked(
        t.kind,
        t.advantage,
        t.traits[0],
        t.traits[1],
        t.traits[2],
        t.traits[3],
        t.traits[4],
        t.traits[5],
        t.traits[6]
      )
    ));
  }

  /**
   * Reseeds entropy with mint amount offset.
   * @param seed random seed
   * @param offset additional entropy during mint
   * @return rotated seed
   */
  function _reseedWithIndex(uint256 seed, uint32 offset) internal pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(seed, offset)));
  }

  /**
   * Allow private sales.
   */
  function mintToAddress(uint256 amount, address recipient, uint256 originSeed) external onlyOwner {
    require(minted + amount <= MAX_TOKENS, "minted out");
    require(amount > 0, "invalid mint amount");
    
    Kind kind;
    uint256 seed;
    for (uint32 i; i < amount; i++) {
      minted++;
      seed = _reseedWithIndex(originSeed, minted);
      kind = _generateAndStoreTraits(minted, seed, 0).kind;
      _safeMint(recipient, minted);
      emit Mint(kind == Kind.RABBIT ? "RABBIT" : kind == Kind.FOX ? "FOX" : "HUNTER", recipient, minted);
    }
  }

  /**
   * Allows owner to withdraw funds from minting.
   */
  function withdraw() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  /**
   * Override transfer to avoid the approval step during staking.
   */
  function transferFrom(address from, address to, uint256 tokenId) public override(IFoxGameNFT, ERC721Upgradeable) {
    if (msg.sender != address(foxGame)) {
      require(_isApprovedOrOwner(msg.sender, tokenId), "transfer not owner nor approved");
    }
    _transfer(from, to, tokenId);
  }

  /**
   * Override NFT token uri. Calls into traits contract.
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "nonexistent token");
    return foxTraits.tokenURI(uint16(tokenId));
  }

  /**
   * Ennumerate tokens by owner.
   */
  function tokensOf(address owner) external view returns (uint16[] memory) {
    uint32 tokenCount = uint32(balanceOf(owner));
    uint16[] memory tokensId = new uint16[](tokenCount);
    for (uint32 i; i < tokenCount; i++){
      tokensId[i] = uint16(tokenOfOwnerByIndex(owner, i));
    }
    return tokensId;
  }

  /**
   * Overridden to resolve multiple inherited interfaces.
   */
  function ownerOf(uint256 tokenId) public view override(IFoxGameNFT, ERC721Upgradeable) returns (address) {
    return super.ownerOf(tokenId);
  }

  /**
   * Overridden to resolve multiple inherited interfaces.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override(IFoxGameNFT, ERC721Upgradeable) {
    super.safeTransferFrom(from, to, tokenId, _data);
  }
}