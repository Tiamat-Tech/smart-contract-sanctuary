// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IToken.sol";
import "../interfaces/IPT.sol";
import "../interfaces/IArena.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

contract Arena is IArena, Ownable, ReentrancyGuard, IERC721Receiver, Pausable {
    using Strings for uint256;

    // struct to store a stake's token, owner, and the time it's staked at
    struct Stake {
        uint256 tokenId;
        uint80 stakedAt; // stake time
        address owner;
    }

    uint256 private numPetsStaked;

    event TokenStaked(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 value
    );
    event TokenClaimed(
        uint256 indexed tokenId,
        bool indexed unstaked,
        uint256 earned
    );

    struct Pet {
        uint256 strength;
        uint256 magic;
        uint256 dexterity;
        uint256 wisdom;
        uint256 intelligence;
    }

    struct ArenaInfo {
        string arenaName;
        uint256 strength;
        uint256 magic;
        uint256 dexterity;
        uint256 wisdom;
        uint256 intelligence;
    }

    ArenaInfo squidGame = ArenaInfo("Squid Game", 3, 1, 4, 8, 1);
    ArenaInfo deathmatch = ArenaInfo("Deathmatch", 8, 4, 7, 3, 1);
    ArenaInfo escapeRoom = ArenaInfo("Escape room", 2, 4, 6, 9, 1);

    //mapping(uint16 => ArenaInfo) arenas;

    ArenaInfo[3] arenas;

    // maps tokenId to Pet
    mapping(uint256 => Pet) private _tokenDetails;

    //tokenId with the biggest score
    mapping(uint256 => uint256) public scores;

    //mapping (address => uint[]) public scores; //

    // reference to Token contract
    IToken public token;
    // reference to the $PT contract for minting $PT earnings
    IPT public pt;

    // maps tokenId to stake
    mapping(uint256 => Stake) private arena;

    // the time pet have to play and cannot be unstaked until then
    uint256 public stakeTime;
    // there will only ever be (roughly) 2.4 billion $GP earned through staking
    uint256 public constant MAXIMUM_GLOBAL_PT = 2880000000 ether;

    // amount of $PT earned so far
    uint256 public totalPTEarned;

    // emergency rescue to allow unstaking without any checks but without $GP
    bool public rescueEnabled = false;

    //the time game starts
    uint256 startTime;

    /**
     */
    constructor() {
        _pause();
        arenas[0] = squidGame;
        arenas[1] = deathmatch;
        arenas[2] = escapeRoom;
    }

    /** CRITICAL TO SETUP */

    modifier requireContractsSet() {
        require(
            address(token) != address(0) && address(pt) != address(0),
            "Contracts not set"
        );
        _;
    }

    function setContracts(address _token, address _pt) external onlyOwner {
        token = IToken(_token);
        pt = IPT(_pt);
    }

    function setStakeTime(uint256 _stakeTime) internal onlyOwner {
        stakeTime = _stakeTime * 1 minutes;
    }

    /**
     * generates a pseudorandom number
     * @param seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function random(uint256 seed) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        tx.origin,
                        blockhash(block.number - 1),
                        block.timestamp,
                        seed
                    )
                )
            );
    }

    //to recieve ETH
    receive() external payable {}

    /** STAKING */

    /**
     * adds pets to the Arena and play
     * @param account the address of the staker
     * @param tokenIds the IDs of the Pets to stake
     */
    function addManyToArenaAndPlay(address account, uint256[] calldata tokenIds)
        external
        override
        nonReentrant
    {
        // check if we can remove "account"
        require((stakeTime + startTime > block.timestamp), "game finished");
        require(
            tx.origin == _msgSender() || _msgSender() == address(token),
            "Only EOA"
        );
        require(account == tx.origin, "account to sender mismatch"); // maybe remove
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_msgSender() != address(token)) {
                // chack if we can change to "require"
                require(
                    token.ownerOf(tokenIds[i]) == _msgSender(), // check if we what that only the user himself can call
                    "You don't own this token"
                );

                token.transferFrom(_msgSender(), address(this), tokenIds[i]);
                _addPetToPlay(account, tokenIds[i]);
            }
        }
    }

    /**
     * adds a single Pet to the Arena to play
     * @param account the address of the staker
     * @param tokenId the ID of the Pet to add to Play
     */
    function _addPetToPlay(address account, uint256 tokenId)
        internal
        whenNotPaused
    {
        arena[tokenId] = Stake({
            owner: account,
            tokenId: uint256(tokenId),
            stakedAt: uint80(block.timestamp)
        });
        numPetsStaked += 1;
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function getNumOfStakedNFTs() external view returns (uint256) {
        return numPetsStaked;
    }

    /** UNSTAKING */

    /**
     * realize $PT earnings and optionally unstake tokens from the arena / play
     * to unstake a Pet it will require it has 5 min of play
     * @param tokenIds the IDs of the tokens to claim earnings from
     */
    function claimManyFromArenaAndPlay(
        address account,
        uint256[] calldata tokenIds
    ) external override whenNotPaused nonReentrant {
        require(
            tx.origin == _msgSender() || _msgSender() == address(token),
            "Only EOA"
        );
        require(account == tx.origin, "account to sender mismatch");
        //uint256 playerScore = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            //playerScore += _claimPetFromArena(tokenIds[i]);
            _claimPetFromArena(tokenIds[i]);
        }
        //pt.updateOriginAccess();
        //pt.mint(_msgSender(), playerScore);
    }

    /**
     * realize $PT earnings for a single pet and unstake it
     * @param tokenId the ID of the pet
     * @return playerScore - the players/pet score
     */
    function _claimPetFromArena(uint256 tokenId)
        internal
        returns (uint256 playerScore)
    {
        Stake memory stake = arena[tokenId];
        require(stake.owner == _msgSender(), "Don't own the given token");
        require(
            !(block.timestamp - stake.stakedAt < stakeTime),
            "Still playing in the arena"
        );
        uint256 randomNum = random(numPetsStaked);
        uint256 rndArenaIndex = ((randomNum) % arenas.length); // choose a value from 0 to the number of arenas
        ArenaInfo memory currentArena = arenas[rndArenaIndex];
        playerScore = calculateScore(tokenId, currentArena);
        delete arena[tokenId];
        numPetsStaked -= 1;
        //string memory strPleyerScore = playerScore.toString();
        token.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Pet
        pt.mint(_msgSender(), playerScore);
        scores[tokenId] = playerScore;
        emit TokenClaimed(tokenId, true, playerScore);
    }

    function calculateScore(uint256 tokenId, ArenaInfo memory currentArena)
        internal
        view
        returns (uint256 playerScore)
    {
        //Pet memory pet = token.getTokenDetails(tokenId);
        //_tokenDetails[tokenId] = token.getTokenDetails(tokenId); // check for a better name
        playerScore = random(tokenId);

        uint256 strength = token.getTokenDetails(tokenId).strength;
        uint256 magic = token.getTokenDetails(tokenId).magic;
        uint256 dexterity = token.getTokenDetails(tokenId).dexterity;
        uint256 wisdom = token.getTokenDetails(tokenId).wisdom;
        uint256 intelligence = token.getTokenDetails(tokenId).intelligence;

        //Pet memory pet = Pet(strength,magic,dexterity,wisdom,intelligence);

        return
            playerScore +=
                strength *
                currentArena.strength +
                magic *
                currentArena.magic +
                dexterity *
                currentArena.dexterity +
                wisdom *
                currentArena.wisdom +
                intelligence *
                currentArena.intelligence;
    }

    function startGame(uint256 _stakeTime) external onlyOwner {
        _unpause();
        startTime = block.timestamp;
        stakeTime = _stakeTime;
        //setStakeTime(_stakeTime);
    }

    function endGame() external onlyOwner {
        _pause();
        startTime = 0;
        stakeTime = 0;
    }

    /**
     * emergency unstake tokens
     * @param tokenIds the IDs of the tokens to claim earnings from
     */
    function rescue(uint256[] calldata tokenIds) external nonReentrant {
        require(rescueEnabled, "RESCUE DISABLED");
        uint256 tokenId;
        Stake memory stake;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            stake = arena[tokenId];
            require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
            delete arena[tokenId];
            numPetsStaked -= 1;
            token.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back pets
            emit TokenClaimed(tokenId, true, 0);
        }
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
     * enables owner to pause / unpause contract
     */
    function setPaused(bool _paused) external requireContractsSet onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send to arena directly");
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * allows owner to withdraw funds
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}