//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract WincityLilleAsset1 is ERC1155, ERC1155Pausable, Ownable {
    using Counters for Counters.Counter;

    string name_;
    string symbol_;
    /**
     * Rarity is linked to token id as such:
     * ID 1 = Unique
     * ID 2 to ID 11 = RarityRange 1 (10 cards)
     * ID 12 to ID 111 =  RarityRange 2 (100 cards)
     * ID 112 to ID 1111 =  RarityRange 3 (1000 cards)
     */

    // Total supply for each rarity type
    uint256 public constant RARITY_RANGE1_SUPPLY = 1;
    uint256 public constant RARITY_RANGE2_SUPPLY = 10;
    uint256 public constant RARITY_RANGE3_SUPPLY = 100;
    uint256 public constant RARITY_RANGE4_SUPPLY = 1000;

    // Initial Public supply for each rarity type,
    // can be updated after deploy
    uint256 public constant RARITY_RANGE1_PUBLIC_SUPPLY = 1;
    uint256 public constant RARITY_RANGE2_PUBLIC_SUPPLY = 3;
    uint256 public constant RARITY_RANGE3_PUBLIC_SUPPLY = 10;
    uint256 public constant RARITY_RANGE4_PUBLIC_SUPPLY = 100;

    uint256 private _maxTokenPerTx = 4;

    struct RarityRange {
        // First token ID in this range
        uint256 firstTokenId;
        // Last token ID in this range
        uint256 lastTokenId;
        // First private token ID in this range
        uint256 firstPrivateTokenId;
        // Price for public mint in this range
        uint256 mintPrice;
    }

    // RarityRanges by id
    mapping(uint256 => RarityRange) public rarityRangeById;

    // Public mint starting time in seconds
    uint256 public publicSaleStartTimestamp;

    // Mapping to keep track of the public token minted. By RarityRange id
    mapping(uint256 => Counters.Counter) private publicMintedCounter;

    // Mapping to keep track of the tokens from the private reserve that have already been withdrawn
    mapping(uint256 => bool) private privateTokensWithdrawl;

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * CONSTRUCTOR
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    constructor(
        string memory _uri,
        string memory _name,
        string memory _symbol
    ) ERC1155(_uri) {
        name_ = _name;
        symbol_ = _symbol;

        uint256 rarityRange1FirstId = 1;
        uint256 rarityRange2FirstId = rarityRange1FirstId +
            RARITY_RANGE1_SUPPLY;
        uint256 rarityRange3FirstId = rarityRange2FirstId +
            RARITY_RANGE2_SUPPLY;
        uint256 rarityRange4FirstId = rarityRange3FirstId +
            RARITY_RANGE3_SUPPLY;

        // Initialize the 4 rarity ranges
        rarityRangeById[0] = RarityRange(
            rarityRange1FirstId,
            rarityRange2FirstId - 1,
            rarityRange1FirstId + RARITY_RANGE1_PUBLIC_SUPPLY,
            1 ether
        );
        rarityRangeById[1] = RarityRange(
            rarityRange2FirstId,
            rarityRange3FirstId - 1,
            rarityRange2FirstId + RARITY_RANGE2_PUBLIC_SUPPLY,
            0.7 ether
        );
        rarityRangeById[2] = RarityRange(
            rarityRange3FirstId,
            rarityRange4FirstId - 1,
            rarityRange3FirstId + RARITY_RANGE3_PUBLIC_SUPPLY,
            0.3 ether
        );
        rarityRangeById[3] = RarityRange(
            rarityRange4FirstId,
            rarityRange4FirstId + RARITY_RANGE4_SUPPLY - 1,
            rarityRange4FirstId + RARITY_RANGE4_PUBLIC_SUPPLY,
            0.1 ether
        );

        // The -1 are because the token are not yet minted and we increment
        // the counter after the minting is successful.
        publicMintedCounter[0] = Counters.Counter(rarityRange1FirstId - 1);
        publicMintedCounter[1] = Counters.Counter(rarityRange2FirstId - 1);
        publicMintedCounter[2] = Counters.Counter(rarityRange3FirstId - 1);
        publicMintedCounter[3] = Counters.Counter(rarityRange4FirstId - 1);
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * MODIFIERS
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    modifier whenPublicSaleActive() {
        require(isPublicSaleOpen(), "Public sale not opened.");
        _;
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * OpenZepplin Hooks
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * GETTERS / SETTERS
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setURI(string memory baseURI) external onlyOwner {
        _setURI(baseURI);
    }

    function name() public view returns (string memory) {
        return name_;
    }

    function symbol() public view returns (string memory) {
        return symbol_;
    }

    function setPublicSaleTimestamp(uint256 timestamp) external onlyOwner {
        publicSaleStartTimestamp = timestamp;
    }

    function isPublicSaleOpen() public view returns (bool) {
        return
            block.timestamp >= publicSaleStartTimestamp &&
            publicSaleStartTimestamp != 0;
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    function publicMintPrice(uint256 rarityRangeId)
        public
        view
        returns (uint256)
    {
        require(
            rarityRangeId >= 0 && rarityRangeId <= 3,
            "Invalid RarityRange ID"
        );
        return rarityRangeById[rarityRangeId].mintPrice;
    }

    function setPublicMintPrice(uint256 rarityRangeId, uint256 mintPrice)
        public
        onlyOwner
    {
        require(mintPrice > 0, "mintPrice must be greater than 0");
        require(
            rarityRangeId >= 0 && rarityRangeId <= 3,
            "Invalid RarityRange ID"
        );
        rarityRangeById[rarityRangeId].mintPrice = mintPrice;
    }

    function maxTokenPerTx() public view returns (uint256) {
        return _maxTokenPerTx;
    }

    function setMaxPerTx(uint256 maxPerTx) public onlyOwner {
        require(maxPerTx > 0, "maxPerTx must be greater than 0");
        _maxTokenPerTx = maxPerTx;
    }

    function getRarityRangeById(uint256 id)
        public
        view
        returns (RarityRange memory)
    {
        require(id >= 0 && id <= 3, "Invalid RarityRange ID");
        return rarityRangeById[id];
    }

    function setPublicReserve(uint256 rarityRangeId, uint256 newPublicSupply)
        public
        onlyOwner
    {
        require(
            rarityRangeId >= 0 && rarityRangeId <= 3,
            "Invalid RarityRange ID"
        );
        RarityRange memory rarityRange = getRarityRangeById(rarityRangeId);
        uint256 newFirstPrivateId = rarityRange.firstTokenId + newPublicSupply;
        require(
            newFirstPrivateId != rarityRange.firstPrivateTokenId,
            "Public supply did not change."
        );

        // The +1 bellow for when a range is fully reserved for public sale
        require(
            newFirstPrivateId <= rarityRange.lastTokenId + 1,
            "Higher than max supply."
        );
        uint256 currentPublicSupply = totalSupply(rarityRangeId);
        require(
            currentPublicSupply < newFirstPrivateId,
            "Public supply too low"
        );

        rarityRangeById[rarityRangeId].firstPrivateTokenId = newFirstPrivateId;
    }

    /**
     * totalSupply
     * Current total supply for a given rarityRange. See EIP-1155.
     */
    function totalSupply(uint256 rarityRangeId)
        public
        view
        virtual
        returns (uint256)
    {
        return publicMintedCounter[rarityRangeId].current();
    }

    /**
     * checkClaimStatus
     * Check if a private token has been previously withdrawn
     */
    function checkClaimStatus(uint256 id) public view virtual returns (bool) {
        return privateTokensWithdrawl[id];
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * MINTING
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /**
     * claimTokenFromPrivateReserve
     * Used to "extract" a privately held token and mint it
     * to a given address.
     */
    function claimTokenFromPrivateReserve(
        uint256 rarityRangeId,
        uint256 id,
        address receiver
    ) external onlyOwner returns (uint256) {
        // Do we have a valid RarityRange ID
        require(
            (rarityRangeId >= 0 && rarityRangeId <= 3),
            "Invalid RarityRange ID"
        );

        // Make sure the token has not been previously withdrawn
        require(
            privateTokensWithdrawl[id] == false,
            "Token previously withdrawn"
        );

        RarityRange memory rarityRange = getRarityRangeById(rarityRangeId);

        require(
            (id >= rarityRange.firstPrivateTokenId &&
                id <= rarityRange.lastTokenId),
            "Token ID not eligeble for claim"
        );
        privateTokensWithdrawl[id] = true;
        _mint(receiver, id, 1, "");
        return id;
    }

    /**
     * Check if a private token has been previously withdrawn
     */
    function mintPublicSale(uint256 rarityRangeId, uint256 count)
        external
        payable
        whenPublicSaleActive
        whenNotPaused
        returns (uint256, uint256)
    {
        
        // Do we have a valid RarityRange ID
        require(
            rarityRangeId >= 0 && rarityRangeId <= 3,
            "Invalid RarityRange ID"
        );

        // Do we have enough supply to fullfil the order
        RarityRange memory currentRarityRange = getRarityRangeById(
            rarityRangeId
        );
        uint256 latestId = publicMintedCounter[rarityRangeId].current();
        require(
            latestId + count < currentRarityRange.firstPrivateTokenId,
            "Not Enough Supply"
        );

        // Is count supperior than max per wallet
        require(count > 0 && count <= _maxTokenPerTx, "Invalid count");

        // Check for payment
        require(
            count * currentRarityRange.mintPrice == msg.value,
            "Incorrect amount of ether sent"
        );

        // All good, we can start minting.
        uint256 firstMintedId = latestId + 1;
        for (uint256 i = 0; i < count; i++) {
            _mint(
                msg.sender,
                publicMintedCounter[rarityRangeId].current() + 1,
                1,
                ""
            );
            publicMintedCounter[rarityRangeId].increment();
        }
        uint256 lastMintedId = firstMintedId + count;
        return (firstMintedId, lastMintedId);
    }

    function withdrawAll(address payable recipient) public onlyOwner {
        (bool succeed, bytes memory data) = recipient.call{value: getBalance()}("");
        require(succeed, "Failed to withdraw Ether");
    }

    function withdrawAmount(address payable recipient, uint256 amount) public onlyOwner {
        (bool succeed, bytes memory data) = recipient.call{value: amount}("");
        require(succeed, "Failed to withdraw Ether");
    }
}