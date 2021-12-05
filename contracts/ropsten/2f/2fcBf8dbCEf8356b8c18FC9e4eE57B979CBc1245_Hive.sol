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
    event BearsAttacked(address indexed owner, uint256 indexed nonce, uint256 successes, uint256 value, uint256 errors);
    event TokenClaimed(address indexed owner, uint256 tokenId, uint256 earned);

    // reference to the Bees NFT contract
    CryptoBees beesContract = CryptoBees(0x814A949B158C5EB9E3f0fE3188de30F6dB230A13);
    // reference to the $HONEY contract for minting $HONEY earnings
    Honey honeyContract = Honey(0x3b6F57900FAb6f0EC8D3d1d3538159eE96B5c105);

    // maps tokenId to hives
    mapping(uint256 => BeeHive) public hives;

    // mapping(address => uint256[]) public owners;
    // maps alpha to all Wolf stakes with that alpha
    // any rewards distributed when no wolves are staked
    // uint256 public unaccountedRewards = 0;
    // amount of $HONEY due for each alpha point staked
    // uint256 public woolPerAlpha = 0;

    // bee earn 200 $HONEY per day
    uint256 public constant DAILY_HONEY_RATE = 400 ether;
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
            emit TokenClaimed(_msgSender(), tokenId, owed);
        } else {
            delete hives[hiveId].bees[tokenId];
            hives[hiveId].occupancy -= 1;
            hives[newHiveId].occupancy += 1;
            hives[newHiveId].bees[tokenId] = Bee({owner: _msgSender(), tokenId: uint16(tokenId), value: uint80(block.timestamp)}); // reset stake
            emit AddedToHive(_msgSender(), newHiveId, tokenId, block.timestamp);
        }
    }

    /** ATTACKS */

    function manyBearsAttack(
        uint256 nonce,
        uint16[] calldata tokenIds,
        uint16[] calldata hiveIds,
        bool transfer
    ) external whenNotPaused _updateEarnings {
        require(tokenIds.length == hiveIds.length, "THE ARGUMENTS LENGTHS DO NOT MATCH");
        uint256 owed = 0;
        uint256 successes = 0;
        uint256 errors = 0;
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
            uint256 hiveId = hiveIds[i];
            // check if bear can attack
            if (hives[hiveId].lastStolenHoneyTimestamp + hiveCooldown > block.timestamp) {
                errors += 1;
                continue;
            }

            uint256 num = ((random(tokenIds[i]) & 0xFFFF) % 100);
            if (num < 50) {
                owed += 10000 ether;
                if (!transfer) beesContract.increateTokensPot(tokenIds[i], 10000);
                hives[hiveId].lastStolenHoneyTimestamp = uint48(block.timestamp);
                hives[hiveId].successfulAttacks += 1;
                successes += 1;
            }
            beesContract.updateTokensLastAttack(tokenIds[i], uint48(block.timestamp));
            hives[hiveId].totalAttacks += 1;
        }
        BearsAttacked(_msgSender(), nonce, successes, owed, errors);
        if (transfer && owed > 0) honeyContract.mint(_msgSender(), owed);
    }

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

    function getInfoOnHive(uint256 hiveId) public view returns (string memory) {
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
                    uint8(hives[hiveId].totalCollections).toString()
                )
            );
    }

    function getInfoOnHives() public view returns (string memory) {
        string memory result;

        for (uint16 i = 0; i < totalNumberOfHives; i++) {
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
                    ";"
                )
            );
        }
        return result;
    }

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
}