// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Player456Game is ERC721, ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    bytes32 public constant FRONTMAN_ROLE = keccak256("FRONTMAN_ROLE");

    uint256 public MAX_PLAYERS_GAME = 456;
    uint256 public playerPrice = 55000000000000000; //0.055 ETH
    bool public saleIsActive = false;
    uint256 public currentRound = 0;
    uint256 public mintedPlayersForRound = 0;

    constructor() ERC721("Player 456 Game", "PGT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FRONTMAN_ROLE, msg.sender);
    }

    /**
     * Mints Players
     */
    function mintPlayer(uint256 numberOfPlayers) public payable {
        require(saleIsActive, "Sale must be active to mint a Player");

        // I will leave this here to check later if we want to limit max mint per wallet
        // require(numberOfPlayers <= maxPlayerPurchase, "Can only mint 20 players at a time");

        require(
            (mintedPlayersForRound + numberOfPlayers) <= MAX_PLAYERS_GAME,
            "Purchase would exceed max supply of Players"
        );

        require((playerPrice * numberOfPlayers) <= msg.value, "Ether value sent is not correct");

        _safeMint(msg.sender, _tokenIdCounter.current());
        _tokenIdCounter.increment();

        mintedPlayersForRound = mintedPlayersForRound + numberOfPlayers;
        if (mintedPlayersForRound == 456) {
            saleIsActive = false;
            currentRound == 1;
        }
    }

    function startSale() public onlyRole(FRONTMAN_ROLE) {
        require(currentRound == 0, "Sale was already started once.");
        saleIsActive = true;
    }

    function nextRound() public onlyRole(FRONTMAN_ROLE) {
        currentRound++;
        saleIsActive = true;
        mintedPlayersForRound = 0;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}