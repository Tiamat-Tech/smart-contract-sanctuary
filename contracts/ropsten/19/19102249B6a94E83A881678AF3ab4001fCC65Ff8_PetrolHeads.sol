// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./libs/RandomlyAssigned.sol";

/**
  _____     _             _ _    _                _     
 |  __ \   | |           | | |  | |              | |    
 | |__) |__| |_ _ __ ___ | | |__| | ___  __ _  __| |___ 
 |  ___/ _ \ __| '__/ _ \| |  __  |/ _ \/ _` |/ _` / __|
 | |  |  __/ |_| | | (_) | | |  | |  __/ (_| | (_| \__ \
 |_|   \___|\__|_|  \___/|_|_|  |_|\___|\__,_|\__,_|___/                                                    
*/
contract PetrolHeads is Ownable, Pausable, RandomlyAssigned, ERC721Enumerable {
    using Counters for Counters.Counter;

    uint256 public constant MAX_TOKENS = 8888;
    Counters.Counter private _purchaseCounter;
    uint256 public constant GIVEAWAY_TOKENS = 88;
    Counters.Counter private _giveawayCounter;
    uint256 public constant TEAM_RESERVE_TOKENS = 44;
    Counters.Counter private _teamReserveCounter;

    uint256 public constant PRICE = 0.03 ether;
    uint256 public constant PURCHASE_LIMIT = 10;
    string public metadataBaseURI = "";

    constructor(string memory baseURI)
        ERC721("PetrolHeads", "PH")
        RandomlyAssigned(MAX_TOKENS, 0)
    {
        metadataBaseURI = baseURI;
    }

    /// @notice purchase tokens by certain PRICE, up to PURCHASE_LIMIT amount, token ids are randomly assigned
    /// @param numberOfTokens - number of tokens you want to purchase, up to PURCHASE_LIMIT
    function purchase(uint256 numberOfTokens) external payable whenNotPaused {
        require(
            _purchaseCounter.current() + numberOfTokens <=
                MAX_TOKENS - GIVEAWAY_TOKENS - TEAM_RESERVE_TOKENS,
            "Maximum purchase amount has been reached"
        );
        require(
            numberOfTokens <= PURCHASE_LIMIT,
            "Can only mint up to 20 tokens"
        );
        require(
            PRICE * numberOfTokens <= msg.value,
            "ETH amount is not sufficient"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _purchaseCounter.increment();
            _mintToken(msg.sender);
        }
    }

    /// @notice only owner can giveaway tokens to certain receiver
    /// @param receiver - receiver of NFT, token id randomly assigned
    function giveaway(address receiver) external onlyOwner whenNotPaused {
        require(
            _giveawayCounter.current() < GIVEAWAY_TOKENS,
            "Maximum giveaway amount has been reached"
        );
        _giveawayCounter.increment();
        _mintToken(receiver);
    }

    /// @notice mint tokens reserved for the PetrolHeads team
    /// @param receiver - receiver of NFT, token id randomly assigned
    function teamMint(address receiver) external onlyOwner whenNotPaused {
        require(
            _teamReserveCounter.current() < TEAM_RESERVE_TOKENS,
            "Maximum team reserve amount has been reached"
        );
        _teamReserveCounter.increment();
        _mintToken(receiver);
    }

    /// @notice only owner can set base uri for NFT data
    /// @param baseURI - base url assigned to the contract
    function setBaseURI(string memory baseURI) external onlyOwner {
        metadataBaseURI = baseURI;
    }

    /// @notice pause the contract, disables mint functions (purchase, giveaway, teamMint)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice unpause the contract, enables mint functions (purchase, giveaway, teamMint)
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice only owner can withdraw found earned with purchase
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool succeed, ) = msg.sender.call{value: balance}("");
        require(succeed, "Failed to withdraw Ether");
    }

    /// @dev _minToken used in mint functions (purchase, giveaway, teamMint)
    function _mintToken(address receiver) private {
        uint256 next = nextToken();
        _safeMint(receiver, next);
    }

    /// @dev sets metadataBaseURI as baseURI for the contract
    function _baseURI() internal view virtual override returns (string memory) {
        return metadataBaseURI;
    }

    /// @notice returns all NFT ids certain address contains
    /// @param owner - specified address from which it returns ids
    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 numOfTokens = balanceOf(owner);

        uint256[] memory tokens = new uint256[](numOfTokens);
        for (uint256 i = 0; i < numOfTokens; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokens;
    }

    /// @notice amount of tokens still available for purchase
    function availableForPurchase() external view returns (uint256) {
        return
            MAX_TOKENS -
            GIVEAWAY_TOKENS -
            TEAM_RESERVE_TOKENS -
            purchasedCount();
    }

    /// @notice amount of tokens already purchased
    function purchasedCount() public view returns (uint256) {
        return _purchaseCounter.current();
    }

    /// @notice amount of tokens that were minted as giveaway
    function giveawayCount() external view returns (uint256) {
        return _giveawayCounter.current();
    }

    /// @notice amount of tokens minted for the team
    function teamReserveCount() external view returns (uint256) {
        return _teamReserveCounter.current();
    }
}