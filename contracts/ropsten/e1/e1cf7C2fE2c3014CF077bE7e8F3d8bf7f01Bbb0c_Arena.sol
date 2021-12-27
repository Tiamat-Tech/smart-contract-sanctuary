// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IToken.sol";
import "../interfaces/IPT.sol";
import "../interfaces/IArena.sol";

contract Arena is IArena, Ownable, ReentrancyGuard, IERC721Receiver, Pausable {
    // struct to store a stake's token, owner, and the time it's staked at
    struct Stake {
        uint16 tokenId;
        uint80 stakedAt;
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

    // reference to Token contract
    IToken public token;
    // reference to the $PT contract for minting $PT earnings
    IPT public pt;

    // maps tokenId to stake
    mapping(uint256 => Stake) private arena;

    // wizards must have 0.3 days worth of $PT to unstake or else they're still guarding the arena
    uint256 public stakeTime = 0.3 days;
    // there will only ever be (roughly) 2.4 billion $GP earned through staking
    uint256 public constant MAXIMUM_GLOBAL_PT = 2880000000 ether;

    // amount of $PT earned so far
    uint256 public totalPTEarned;

    // emergency rescue to allow unstaking without any checks but without $GP
    bool public rescueEnabled = false;

    /**
     */
    constructor() {
        _pause();
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

    function setStakeTime(uint256 _stakeTime) external onlyOwner {
        stakeTime = _stakeTime;
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

    /** STAKING */

    /**
     * adds pets to the Arena and play
     * @param account the address of the staker
     * @param tokenIds the IDs of the Pets to stake
     */
    function addManyToArenaAndPlay(address account, uint16[] calldata tokenIds)
        external
        override
        nonReentrant
    {
        require(
            tx.origin == _msgSender() || _msgSender() == address(token),
            "Only EOA"
        );
        require(account == tx.origin, "account to sender mismatch");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_msgSender() != address(token)) {
                require(
                    token.ownerOf(tokenIds[i]) == _msgSender(),
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
            tokenId: uint16(tokenId),
            stakedAt: uint80(block.timestamp)
        });
        numPetsStaked += 1;
        emit TokenStaked(account, tokenId, block.timestamp);
    }

    /** CLAIMING / UNSTAKING */

    /**
     * realize $PT earnings and optionally unstake tokens from the arena / play
     * to unstake a Pet it will require it has 0.3 days of play
     * @param tokenIds the IDs of the tokens to claim earnings from
     */
    function claimManyFromArenaAndPlay(
        address account,
        uint16[] calldata tokenIds
    ) external override whenNotPaused nonReentrant {
        require(
            tx.origin == _msgSender() || _msgSender() == address(token),
            "Only EOA"
        );
        require(account == tx.origin, "account to sender mismatch");
        uint256 owed = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            owed += _claimPetFromArena(tokenIds[i]);
        }
        pt.updateOriginAccess();
        if (owed == 0) {
            return;
        }
        pt.mint(_msgSender(), owed);
    }

    /**
     * realize $PT earnings for a single Wizard and optionally unstake it
     * @param tokenId the ID of the Wizards to claim earnings from
     * @return owed - the amount of $PT earned
     */
    function _claimPetFromArena(uint256 tokenId)
        internal
        returns (uint256 owed)
    {
        Stake memory stake = arena[tokenId];
        require(stake.owner == _msgSender(), "Don't own the given token");
        require(
            !(block.timestamp - stake.stakedAt < stakeTime),
            "Still playing in the arena"
        );
        owed = 0;
        if (totalPTEarned < MAXIMUM_GLOBAL_PT) {
            owed = 1000;
        }
        delete arena[tokenId];
        numPetsStaked -= 1;
        // Always transfer last to guard against reentrance
        token.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Pet

        emit TokenClaimed(tokenId, true, owed);
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
            token.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Wizards
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
}