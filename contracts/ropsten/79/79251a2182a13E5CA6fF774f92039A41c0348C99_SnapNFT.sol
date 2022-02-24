// contracts/SnapMarket.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract SnapNFT is ERC721URIStorage, ERC721Holder, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _gameId;
    Counters.Counter private _availableId;
    Counters.Counter private _tokenIds;

    constructor() ERC721("SnapGame", "SNAP") {}

    uint256 lastAvailablePlayer = 0;
    uint totalSupply = 100;
    uint maxPerRequest = 10;

    struct availablePlayer {
        uint256 tokenId;
        address player;
        bool available;
    }

    struct gameInstance {
        availablePlayer player1;
        availablePlayer player2;
        bool inPlay;
    }

    mapping(uint256 => gameInstance) private gameInstanceIDs;
    mapping(uint256 => availablePlayer) private availablePlayerIDs;

    event NewGame(uint256 gameInstanceId, address indexed player1, uint256 token1, address indexed player2, uint256 token2, bool stataus);

    // Mint new tokens
    function createTokens(
        uint quantity
        ) public {
            require(quantity > 0,"You must request at least one.");
            require(_tokenIds.current() + quantity <= totalSupply,"The number requested exceeds supply");
            require(quantity <= maxPerRequest,"You can only request 10 tokens at a time");
            for (uint i = 0; i < quantity; i++){
                _tokenIds.increment();
                uint256 newItemId = _tokenIds.current();
                _mint(msg.sender, newItemId);
                _setTokenURI(newItemId, "");
                // delegate approval to the market address
                setApprovalForAll(address(this), true);
            }
    }

    /* Allows a player to be to be challenged */
    function makeAvailable(
        uint256 tokenId
        ) private onlyOwner returns (uint256) {
        _availableId.increment();
        uint256 availableId = _availableId.current();

        availablePlayerIDs[availableId] =  availablePlayer(
            tokenId,
            msg.sender,
            true
        );

        // transfer custody of token to this contract
        safeTransferFrom(msg.sender, address(this), tokenId);

        return availableId;
    }

    // create a game instance, will find next avaible player
    function createGameInstance(
        uint256 tokenId
        )
        public onlyOwner returns(uint256) {
        
        uint256 gameId = 0;
        uint256 _nextPlayerId = 0;

        // make chllenger available
        uint256 challengerId = makeAvailable(tokenId);

        // need to find a participant
        bool foundParticipant = false;
        for (uint256 nextPlayerId = lastAvailablePlayer; nextPlayerId <= _availableId.current(); nextPlayerId++){
            if (nextPlayerId != challengerId && availablePlayerIDs[nextPlayerId].available==true) {
                    foundParticipant = true;
                    lastAvailablePlayer = nextPlayerId;
                    _nextPlayerId = nextPlayerId;
                    break;
                } 
            }

        if (foundParticipant) {
            availablePlayerIDs[challengerId].available = false;
            availablePlayerIDs[_nextPlayerId].available = false;
            _gameId.increment();
            gameId = _gameId.current();
            gameInstanceIDs[gameId] = gameInstance(
                availablePlayerIDs[challengerId],
                availablePlayerIDs[_nextPlayerId],
                true
                );
            emit NewGame(
                gameId,
                gameInstanceIDs[gameId].player1.player,
                gameInstanceIDs[gameId].player1.tokenId,
                gameInstanceIDs[gameId].player2.player,
                gameInstanceIDs[gameId].player2.tokenId,
                gameInstanceIDs[gameId].inPlay);   
        }
        return gameId;
        }

        //getTokenBeacon
        function getBeacon(uint256 gameId) 
        public view returns(uint256) {
            // this needs changing
            uint256 beaconId = (block.timestamp % 60) % _tokenIds.current();

            return beaconId;
        }

        //claimToken
        function claimToken(uint256 gameId)
        public {
            uint256 currentBeacon = getBeacon(gameId);
            // if the sender owns either token and the beacon matches, then they get them all
            require((msg.sender == gameInstanceIDs[gameId].player1.player) || (msg.sender == gameInstanceIDs[gameId].player2.player), "You're not in the game, these are no longer your tokens!");
            require((gameInstanceIDs[gameId].player1.tokenId == currentBeacon) || (gameInstanceIDs[gameId].player1.tokenId == currentBeacon), "Neither token matches the beacon!");

            safeTransferFrom(address(this),msg.sender,gameInstanceIDs[gameId].player1.tokenId);
            safeTransferFrom(address(this),msg.sender,gameInstanceIDs[gameId].player2.tokenId);
        }

        // some getter functions
        function getAvaiablePlayerId() 
        public view returns(uint256) {
            return _availableId.current();
        }

        function getGameId() 
        public view returns(uint256) {
            return _gameId.current();
        }


}