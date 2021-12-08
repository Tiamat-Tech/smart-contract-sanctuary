// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ICryptoBees.sol";
import "./IHoney.sol";
import "./IHive.sol";
import "./IAttack.sol";

contract Hive is IHive, Ownable, IERC721Receiver, Pausable {
    using Strings for uint256;
    using Strings for uint48;
    using Strings for uint32;
    using Strings for uint16;
    using Strings for uint8;

    event AddedToHive(address indexed owner, uint256 hiveId, uint256 tokenId, uint256 timestamp);
    event TokenClaimed(address indexed owner, uint256 tokenId, uint256 earned);

    // contract references
    IHoney honeyContract = IHoney(0x3E63Aa06691bc9Fd34637f8324D851e51df823D4);
    ICryptoBees beesContract;
    IAttack attackContract;

    // maps tokenId to hives
    mapping(uint256 => BeeHive) public hives;

    // bee earn 400 $HONEY per day
    uint256 public constant DAILY_HONEY_RATE = 400 ether;
    // bee must have stay 1 day in the hive
    uint256 public constant MINIMUM_TO_EXIT = 1 days;
    // there will only ever be (roughly) 2.4 billion $HONEY earned through staking
    uint256 public constant MAXIMUM_GLOBAL_HONEY = 2400000000 ether;

    // amount of $HONEY earned so far
    uint256 public totalHoneyEarned;
    // number of Bees staked
    uint256 public totalBeesStaked;
    // the last time $HONEY was claimed
    uint256 public lastClaimTimestamp;

    // emergency rescue to allow unstaking without any checks but without $HONEY
    bool public rescueEnabled = false;

    /**
     */
    constructor() {}

    function setHoneyContract(address _HONEY_CONTRACT) external onlyOwner {
        honeyContract = IHoney(_HONEY_CONTRACT);
    }

    function setBeesContract(address _BEES_CONTRACT) external onlyOwner {
        beesContract = ICryptoBees(_BEES_CONTRACT);
    }

    /** STAKING */
    function calculateOwed(uint256 since) internal view returns (uint256 owed) {
        if (totalHoneyEarned < MAXIMUM_GLOBAL_HONEY) {
            owed = ((block.timestamp - since) * DAILY_HONEY_RATE) / 1 days;
        } else if (since > lastClaimTimestamp) {
            owed = 0; // $HONEY production stopped already
        } else {
            owed = ((lastClaimTimestamp - since) * DAILY_HONEY_RATE) / 1 days; // stop earning additional $HONEY if it's all been earned
        }
    }

    function calculateBeeOwed(uint256 hiveId, uint256 tokenId) external view returns (uint256 owed) {
        uint256 since = hives[hiveId].bees[tokenId].since;
        owed = calculateOwed(since);
    }

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
            // require(beesContract.getTokenData(tokenIds[i])._type == 1, "TOKEN MUST BE A BEE");
            // dont do this step if its a mint + stake
            if (_msgSender() != address(beesContract)) {
                require(beesContract.getOwnerOf(tokenIds[i]) == _msgSender(), "AINT YO TOKEN");
                beesContract.performTransferFrom(_msgSender(), address(this), tokenIds[i]);
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
        uint256 index = hives[hiveId].beesArray.length;
        hives[hiveId].bees[tokenId] = Bee({owner: account, tokenId: uint16(tokenId), index: uint8(index), since: uint48(block.timestamp)});
        hives[hiveId].beesArray.push(uint16(tokenId));
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
        Bee memory bee = hives[hiveId].bees[tokenId];
        require(bee.owner == _msgSender(), "YOU ARE NOT THE OWNER");
        // require(!(block.timestamp - stake.value < MINIMUM_TO_EXIT), 'YOU NEED MORE HONEY TO GET OUT OF THE HIVE');
        owed = calculateOwed(bee.since);
        if (newHiveId == 0) {
            beesContract.performSafeTransferFrom(address(this), _msgSender(), tokenId); // send back Sheep
            delete hives[hiveId].bees[tokenId];

            totalBeesStaked -= 1;
            emit TokenClaimed(_msgSender(), tokenId, owed);
        } else {
            uint256 index = hives[hiveId].bees[tokenId].index;
            uint256 lastIndex = hives[hiveId].beesArray.length - 1;
            uint256 lastTokenIndex = hives[hiveId].beesArray[lastIndex];
            hives[hiveId].beesArray[index] = uint16(lastTokenIndex);
            hives[hiveId].beesArray.pop();

            delete hives[hiveId].bees[tokenId];
            uint256 newIndex = hives[newHiveId].beesArray.length;

            hives[newHiveId].bees[tokenId] = Bee({owner: _msgSender(), tokenId: uint16(tokenId), index: uint8(newIndex), since: uint48(block.timestamp)}); // reset stake
            emit AddedToHive(_msgSender(), newHiveId, tokenId, block.timestamp);
        }
    }

    // GETTERS / SETTERS
    function getLastStolenHoneyTimestamp(uint256 hiveId) external view returns (uint256 lastStolenHoneyTimestamp) {
        lastStolenHoneyTimestamp = hives[hiveId].lastStolenHoneyTimestamp;
    }

    function getHiveOccupancy(uint256 hiveId) external view returns (uint256 occupancy) {
        occupancy = hives[hiveId].beesArray.length;
    }

    function getBeeSinceTimestamp(uint256 hiveId, uint256 tokenId) external view returns (uint256 since) {
        since = hives[hiveId].bees[tokenId].since;
    }

    function getBeeTokenId(uint256 hiveId, uint256 index) external view returns (uint256 tokenId) {
        tokenId = hives[hiveId].beesArray[index];
    }

    function setBeeSince(
        uint256 hiveId,
        uint256 tokenId,
        uint48 since
    ) external {
        require(_msgSender() == address(attackContract), "ONLY ATTACK CONTRACT CAN CALL THIS");
        hives[hiveId].bees[tokenId].since = since;
    }

    function incSuccessfulAttacks(uint256 hiveId) external {
        require(_msgSender() == address(attackContract), "ONLY ATTACK CONTRACT CAN CALL THIS");
        hives[hiveId].successfulAttacks += 1;
    }

    function incTotalAttacks(uint256 hiveId) external {
        require(_msgSender() == address(attackContract), "ONLY ATTACK CONTRACT CAN CALL THIS");
        hives[hiveId].totalAttacks += 1;
    }

    function setLastStolenHoneyTimestamp(uint256 hiveId, uint48 timestamp) external {
        require(_msgSender() == address(attackContract), "ONLY ATTACK CONTRACT CAN CALL THIS");
        hives[hiveId].lastStolenHoneyTimestamp = timestamp;
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
     * enables owner to pause / unpause
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
                    uint16(hives[hiveId].beesArray.length).toString(),
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

    function getInfoOnHives(uint16 start, uint256 end) public view returns (string memory) {
        string memory result;
        uint256 to = end > 0 ? end : beesContract.getMinted();
        for (uint16 i = start; i < to; i++) {
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
                    uint16(hives[i].beesArray.length).toString(),
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
        return uint256(keccak256(abi.encodePacked(tx.origin, block.timestamp, seed))); //blockhash(block.number - 1),
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