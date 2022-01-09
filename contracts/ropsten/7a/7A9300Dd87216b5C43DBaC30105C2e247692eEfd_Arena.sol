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

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Arena is IArena, Ownable, ReentrancyGuard, IERC721Receiver, Pausable {
    using Strings for uint256;
    using SafeMath for uint256;
    // struct to store a stake's token, owner, and the time it's staked at
    struct Stake {
        uint256 tokenId;
        uint80 stakedAt; // stake time
        address owner;
    }

    // number of staked NFTs in Arena
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
    ArenaInfo escapeRoom = ArenaInfo("Escape room", 2, 4, 6, 9, 2);

    ArenaInfo[] arenas;

    // is game ended
    bool gameEnded = true;

    // maps tokenId to Pet
    mapping(uint256 => Pet) private _tokenDetails;

    //maps tokenId to score
    mapping(uint256 => uint256) public scores;

    // reference to Token contract
    IToken public token;
    // reference to the $PT contract for minting $PT earnings
    IPT public pt;

    // the current Arena
    ArenaInfo currentArena;

    // maps tokenId to stake
    mapping(uint256 => Stake) private stakedToArena;

    // the time pet have to play and cannot be unstaked until then
    uint256 public stakeTime;
    // there will only ever be (roughly) 2.4 billion $GP earned through staking
    uint256 public constant MAXIMUM_GLOBAL_PT = 2880000000 ether;

    // amount of $PT earned so far
    uint256 public totalPTEarned;

    // emergency rescue to allow unstaking without any checks but without $GP
    bool public rescueEnabled = false;

    //the time game starts
    uint256 startGameTime;

    /**
     */
    constructor() {
        _pause();
        arenas.push(squidGame);
        arenas.push(deathmatch);
        arenas.push(escapeRoom);
    }

    /** CRITICAL TO SETUP */

    modifier requireContractsSet() {
        require(
            address(token) != address(0) && address(pt) != address(0),
            "Contracts not set"
        );
        _;
    }

    // set the contracts that are working with the Arena contract
    function setContracts(address _token, address _pt) external onlyOwner {
        token = IToken(_token);
        pt = IPT(_pt);
    }

    // set the time that is allowed to stake
    function setStakeTime(uint256 _stakeTime) internal onlyOwner {
        stakeTime = _stakeTime * 1 minutes;
    }

    // set new arena
    function addNewArena(ArenaInfo[] memory newArenas) internal onlyOwner {
        for (uint256 i; i < newArenas.length; i++) {
            arenas.push(newArenas[i]);
        }
    }

    function getCurrentArena()
        external
        view
        onlyOwner
        returns (string memory arenaName)
    {
        return currentArena.arenaName;
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

    //to recieve ETH to Arena contract
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
        require((stakeTime + startGameTime > block.timestamp), "game finished");
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
        stakedToArena[tokenId] = Stake({
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
     * unstake NTFs from the arena
     * @param tokenIds the IDs of the NFTs to claim
     */
    function claimManyFromArenaAndPlay(
        address account,
        uint256[] calldata tokenIds
    ) external override whenNotPaused nonReentrant {
        require(gameEnded == true, "the game is not ended yet");
        require(
            tx.origin == _msgSender() || _msgSender() == address(token),
            "Only EOA"
        );
        require(account == tx.origin, "account to sender mismatch");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _claimPetFromArena(tokenIds[i]);
        }
    }

    /**
     * unstake a single NFT from the arena and get $PT earnings
     * @param tokenId the ID of the pet
     * @return playerScore - the players/pet score
     */
    function _claimPetFromArena(uint256 tokenId)
        internal
        returns (uint256 playerScore)
    {
        Stake memory stake = stakedToArena[tokenId];
        require(stake.owner == _msgSender(), "Don't own the given token");
        require(
            !(block.timestamp - stake.stakedAt < stakeTime),
            "Still playing in the arena"
        );
        playerScore = calculateScore(tokenId);
        delete stakedToArena[tokenId];
        numPetsStaked -= 1;

        token.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Pet
        pt.mint(_msgSender(), playerScore);
        scores[tokenId] = playerScore;
        emit TokenClaimed(tokenId, true, playerScore);
    }

    // calculate score for a single NFT
    function calculateScore(uint256 tokenId)
        internal
        view
        returns (uint256 playerScore)
    {
        uint256 randomNum = random(tokenId);
        playerScore = ((randomNum) % 650); // choose a value from 0 to the number of arenas

        uint256 strength = token.getTokenDetails(tokenId).strength;
        uint256 magic = token.getTokenDetails(tokenId).magic;
        uint256 dexterity = token.getTokenDetails(tokenId).dexterity;
        uint256 wisdom = token.getTokenDetails(tokenId).wisdom;
        uint256 intelligence = token.getTokenDetails(tokenId).intelligence;

        uint256 score = strength *
            currentArena.strength +
            magic *
            currentArena.magic +
            dexterity *
            currentArena.dexterity +
            wisdom *
            currentArena.wisdom +
            intelligence *
            currentArena.intelligence;

        playerScore += score;

        return playerScore;
    }

    function startGame(uint256 _stakeTime) external onlyOwner {
        _unpause();
        gameEnded = false;
        startGameTime = block.timestamp;
        stakeTime = _stakeTime;
    }

    function endGame(uint256 rndNum) external onlyOwner {
        _pause();
        startGameTime = 0;
        stakeTime = 0;
        uint256 randomNum = random(rndNum);
        uint256 rndArenaIndex = ((randomNum) % arenas.length); // choose a value from 0 to the number of arenas
        currentArena = arenas[rndArenaIndex];
        gameEnded = true;
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
            stake = stakedToArena[tokenId];
            require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
            delete stakedToArena[tokenId];
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