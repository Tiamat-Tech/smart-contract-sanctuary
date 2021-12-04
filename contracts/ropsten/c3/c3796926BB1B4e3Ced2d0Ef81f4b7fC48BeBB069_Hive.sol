// SPDX-License-Identifier: MIT LICENSE

// Needs to update to 0.8.0
pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./CryptoBees.sol";
import "./Honey.sol";

contract Hive is Ownable, IERC721Receiver, Pausable {
    using Strings for uint256;
    using Strings for uint48;
    using Strings for uint32;
    using Strings for uint16;
    using Strings for uint8;

    // struct to store a stake's token, owner, and earning values
    struct Bee {
        address owner;
        uint32 tokenId;
        uint80 value;
    }
    struct Bear {
        address owner;
        uint32 tokenId;
        uint80 value;
        uint80 pot;
    }

    struct BeeHive {
        uint48 startedTimestamp;
        uint48 lastCollectedHoneyTimestamp;
        uint48 lastStolenHoneyTimestamp;
        uint32 subtract;
        uint16 occupancy;
        uint8 successfulAttacks;
        uint8 totalAttacks;
        uint8 successfulCollections;
        uint8 totalCollections;
        mapping(uint256 => Bee) bees;
    }

    event AddedToHive(address indexed owner, uint256 hiveId, uint256 tokenId, uint256 value);
    event AddedToForrest(address indexed owner, uint256 tokenId, uint256 value);
    event BearsAttacked(address indexed owner, uint256 tokenId, uint256 value, bool err);
    event TokenClaimed(uint256 tokenId, uint256 earned);

    // reference to the Bees NFT contract
    CryptoBees beesContract = CryptoBees(0x814A949B158C5EB9E3f0fE3188de30F6dB230A13);
    // reference to the $HONEY contract for minting $HONEY earnings
    Honey honeyContract = Honey(0x3b6F57900FAb6f0EC8D3d1d3538159eE96B5c105);

    // maps tokenId to hives
    mapping(uint256 => BeeHive) public hives;
    mapping(uint256 => Bear) public forrest;

    // mapping(address => uint256[]) public owners;
    // maps alpha to all Wolf stakes with that alpha
    // any rewards distributed when no wolves are staked
    // uint256 public unaccountedRewards = 0;
    // amount of $HONEY due for each alpha point staked
    // uint256 public woolPerAlpha = 0;

    // bee earn 200 $HONEY per day
    uint256 public constant DAILY_HONEY_RATE = 200 ether;
    // bee must have 2 days worth of $HONEY to unstake or else it's too cold
    uint256 public constant MINIMUM_TO_EXIT = 1 days;
    // there will only ever be (roughly) 2.4 billion $HONEY earned through staking
    uint256 public constant MAXIMUM_GLOBAL_HONEY = 2400000000 ether;

    // amount of $HONEY earned so far
    uint256 public totalHoneyEarned;
    // number of Bees staked
    uint256 public totalBeesStaked;
    // the last time $HONEY was claimed
    uint256 public lastClaimTimestamp;

    uint256 public totalNumberOfHives = 100;
    uint256 public hiveCooldown = 60;

    // emergency rescue to allow unstaking without any checks but without $HONEY
    bool public rescueEnabled = false;

    /**
     */
    constructor() {}

    function setHoneyContract(address _HONEY_CONTRACT) external onlyOwner {
        honeyContract = Honey(_HONEY_CONTRACT);
    }

    function setBeesContract(address _BEES_CONTRACT) external onlyOwner {
        beesContract = CryptoBees(_BEES_CONTRACT);
    }

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
        require(account == _msgSender() || _msgSender() == address(beesContract), "DONT GIVE YOUR TOKENS AWAY");
        require(tokenIds.length == hiveIds.length, "THE ARGUMENTS LENGTHS DO NOT MATCH");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_msgSender() != address(beesContract)) {
                // dont do this step if its a mint + stake
                require(beesContract.ownerOf(tokenIds[i]) == _msgSender(), "AINT YO TOKEN");
                beesContract.transferFrom(_msgSender(), address(this), tokenIds[i]);
            } else if (tokenIds[i] == 0) {
                continue; // there may be gaps in the array for stolen tokens
            }

            _addBeeToHive(account, tokenIds[i], hiveIds[i]);
        }
    }

    /**
     * adds Bees to the Hive
     * @param account the address of the staker
     * @param tokenIds the IDs of the Bees
     */
    function addManyToForrest(address account, uint16[] calldata tokenIds) external {
        require(account == _msgSender() || _msgSender() == address(beesContract), "DONT GIVE YOUR TOKENS AWAY");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_msgSender() != address(beesContract)) {
                // dont do this step if its a mint + stake
                require(beesContract.ownerOf(tokenIds[i]) == _msgSender(), "AINT YO TOKEN");
                beesContract.transferFrom(_msgSender(), address(this), tokenIds[i]);
            } else if (tokenIds[i] == 0) {
                continue; // there may be gaps in the array for stolen tokens
            }

            _addBearToForrest(account, tokenIds[i]);
        }
    }

    /**
     * adds a single Bee to a specific Hive
     * @param account the address of the staker
     * @param tokenId the ID of the Bee to add
     */
    function _addBearToForrest(address account, uint256 tokenId) internal whenNotPaused _updateEarnings {
        forrest[tokenId] = Bear({owner: account, pot: 0, tokenId: uint16(tokenId), value: uint80(block.timestamp)});
        // totalBeesStaked += 1;
        emit AddedToForrest(account, tokenId, block.timestamp);
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
        if (hives[hiveId].startedTimestamp == 0) hives[hiveId].startedTimestamp = uint48(block.timestamp);
        hives[hiveId].occupancy += 1;
        hives[hiveId].bees[tokenId] = Bee({owner: account, tokenId: uint16(tokenId), value: uint48(block.timestamp)});
        totalBeesStaked += 1;
        emit AddedToHive(account, hiveId, tokenId, block.timestamp);
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
        require(tokenIds.length == hiveIds.length && tokenIds.length == newHiveIds.length, "THE ARGUMENTS LENGTHS DO NOT MATCH");
        uint256 owed = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            owed += _claimBeeFromHive(tokenIds[i], hiveIds[i], newHiveIds[i]);
        }
        if (owed == 0) return;
        honeyContract.mint(_msgSender(), owed);
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
        Bee memory stake = hives[hiveId].bees[tokenId];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        // require(!(block.timestamp - stake.value < MINIMUM_TO_EXIT), 'YOU NEED MORE HONEY TO GET OUT OF THE HIVE');
        if (totalHoneyEarned < MAXIMUM_GLOBAL_HONEY) {
            owed = ((block.timestamp - stake.value) * DAILY_HONEY_RATE) / 1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $HONEY production stopped already
        } else {
            owed = ((lastClaimTimestamp - stake.value) * DAILY_HONEY_RATE) / 1 days; // stop earning additional $HONEY if it's all been earned
        }
        if (newHiveId == 0) {
            beesContract.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Sheep
            delete hives[hiveId].bees[tokenId];
            hives[hiveId].occupancy -= 1;
            totalBeesStaked -= 1;
            emit TokenClaimed(tokenId, owed);
        } else {
            delete hives[hiveId].bees[tokenId];
            hives[hiveId].occupancy -= 1;
            hives[newHiveId].occupancy += 1;
            hives[newHiveId].bees[tokenId] = Bee({owner: _msgSender(), tokenId: uint16(tokenId), value: uint80(block.timestamp)}); // reset stake
            emit AddedToHive(_msgSender(), newHiveId, tokenId, block.timestamp);
        }
    }

    function manyBearsAttack(
        uint16[] calldata tokenIds,
        uint16[] calldata hiveIds,
        bool transfer
    ) external whenNotPaused _updateEarnings {
        require(tokenIds.length == hiveIds.length, "THE ARGUMENTS LENGTHS DO NOT MATCH");
        uint256 owed = 0;
        bool duplicates;
        for (uint256 i = 0; i < hiveIds.length; i++) {
            for (uint256 y = 0; y < hiveIds.length; y++) {
                if (i != y && hiveIds[i] == hiveIds[y]) duplicates = true;
            }
        }
        require(!duplicates, "CANNOT ATTACK SAME HIVE WITH TWO BEARS");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(beesContract.ownerOf(tokenIds[i]) == _msgSender(), "YOU ARE NOT THE OWNER");

            require(beesContract.getTokenType(tokenIds[i]) == 1, "TOKEN NOT A BEAR");

            // check if bear can attack
            if (hives[i].lastStolenHoneyTimestamp + hiveCooldown > block.timestamp) {
                BearsAttacked(_msgSender(), tokenIds[i], 0, true);
                continue;
            }

            uint256 num = ((random(tokenIds[i]) & 0xFFFF) % 100);
            if (num < 50) {
                owed += 10000 ether;
                if (!transfer) beesContract.increateTokensPot(tokenIds[i], 10000);
                beesContract.updateTokensLastAttack(tokenIds[i], uint48(block.timestamp));
                hives[i].lastStolenHoneyTimestamp = uint48(block.timestamp);
                hives[i].successfulAttacks += 1;
                BearsAttacked(_msgSender(), tokenIds[i], 10000 ether, false);
            } else {
                BearsAttacked(_msgSender(), tokenIds[i], 0, false);
            }
            hives[i].totalAttacks += 1;
        }
        if (transfer && owed > 0) honeyContract.mint(_msgSender(), owed);
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

    function getInfoOnBee(uint256 tokenId, uint256 hiveId) public view returns (Bee memory) {
        return hives[hiveId].bees[tokenId];
    }

    uint48 startedTimestamp;
    uint48 lastCollectedHoneyTimestamp;
    uint48 lastStolenHoneyTimestamp;
    uint32 subtract;
    uint16 occupancy;
    uint8 successfulAttacks;
    uint8 totalAttacks;
    uint8 successfulCollections;
    uint8 totalCollections;

    function getInfoOnHive(uint256 hiveId) public view returns (string memory) {
        uint256 totalHoney;
        for (uint256 i = 0; i < 40000; i++) {
            if (hives[hiveId].bees[i].value > 0) {
                totalHoney += ((block.timestamp - hives[hiveId].bees[i].value) * DAILY_HONEY_RATE) / 1 days;
            }
        }
        return
            string(
                abi.encodePacked(
                    uint48(hives[hiveId].startedTimestamp).toString(),
                    ",",
                    uint48(hives[hiveId].lastCollectedHoneyTimestamp).toString(),
                    ",",
                    uint48(hives[hiveId].lastStolenHoneyTimestamp).toString(),
                    ",",
                    uint32(hives[hiveId].subtract).toString(),
                    ",",
                    uint16(hives[hiveId].occupancy).toString(),
                    ",",
                    uint8(hives[hiveId].successfulAttacks).toString(),
                    ",",
                    uint8(hives[hiveId].totalAttacks).toString(),
                    ",",
                    uint8(hives[hiveId].successfulCollections).toString(),
                    ",",
                    uint8(hives[hiveId].totalCollections).toString(),
                    ",",
                    uint256(totalHoney).toString()
                )
            );
    }

    function getInfoOnHives() public view returns (string memory) {
        string memory result;

        for (uint16 i = 0; i < totalNumberOfHives; i++) {
            uint256 totalHoney;
            for (uint256 y = 0; y < 40000; y++) {
                if (hives[i].bees[y].value > 0) {
                    totalHoney += ((block.timestamp - hives[i].bees[y].value) * DAILY_HONEY_RATE) / 1 days;
                }
            }
            result = string(
                abi.encodePacked(
                    result,
                    uint16(i).toString(),
                    ":",
                    uint48(hives[i].startedTimestamp).toString(),
                    ",",
                    uint48(hives[i].lastCollectedHoneyTimestamp).toString(),
                    ",",
                    uint48(hives[i].lastStolenHoneyTimestamp).toString(),
                    ",",
                    uint32(hives[i].subtract).toString(),
                    ",",
                    uint16(hives[i].occupancy).toString(),
                    ",",
                    uint8(hives[i].successfulAttacks).toString(),
                    ",",
                    uint8(hives[i].totalAttacks).toString(),
                    ",",
                    uint8(hives[i].successfulCollections).toString(),
                    ",",
                    uint8(hives[i].totalCollections).toString(),
                    ",",
                    uint256(totalHoney).toString(),
                    ";"
                )
            );
        }
        return result;
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