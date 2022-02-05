// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TNFT is IERC721Metadata, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    /**
     * @notice current count for tnft minted
     */
    Counters.Counter private _tnftIds;

    /**
     * @notice maintain a list of (market) contracts that can mint and burn a TNFT
     */
    mapping(address => bool) public allowedMinters;


    string baseURI = "https://tangelo.finance/tnft/";

    /**
     * @notice Tangelo DebtNFT struct
     */
    struct NFT {
        // Collection Address of collateral NFT
        address collectionAddress;
        // Unique token id of collateral NFT
        uint256 collectionTokenId;
        // loan principal
        uint256 principal;
        // Total loan Fee (Interest)
        uint256 fee;
        // timestamp when loan was originated
        uint48 createdAt;
        // loan duration
        uint48 termDays;
    }

    /**
     * @notice mapping to store tnftId to NFT Struct
     */
    mapping(uint256 => NFT) private idToNFT;

    /**
     * @notice multiplier of total owed amount i.e. auction price on day 1
     */
    uint16 private auctionStartingMultiplierPercent = 200;

    /**
     * @notice daily price drop percent
     */
    uint8 private auctionDiscountFactorPercent = 10;

    /**
     * @notice number of days foreclosure is disallowed after termLength ends
     */
    uint8 private graceDays = 1;

    /**
     * @notice modifier to check if caller is one of allowedMinters
     */
    modifier onlyMinters(address sender) {
        require(allowedMinters[sender], "Not an allowed minter");
        _;
    }

    constructor() ERC721("Tangelo NFT", "TNFT") {}

    /**
     * @notice lets an allowedMinter mint a new TNFT to represent a new debt position
     * @dev only valid callers are allowedMinters
     * @param borrower address of borrower with this debt position
     * @param collectionAddress address of collateral NFT collection
     * @param collectionTokenId unique id of collateral NFT
     * @param principal principal amount with this debt position
     * @param fee total fee (interest) attached with this debt position
     * @param termDays loan term (in days) with this debt position
     */
    function mint(
        address borrower,
        address collectionAddress,
        uint256 collectionTokenId,
        uint256 principal,
        uint256 fee,
        uint48 termDays
    ) public onlyMinters(msg.sender) {
        _tnftIds.increment();
        uint256 tnftId = _tnftIds.current();
        idToNFT[tnftId] = NFT(
            collectionAddress,
            collectionTokenId,
            principal,
            fee,
            uint48(block.timestamp),
            termDays
        );
        _mint(borrower, tnftId);
    }

    /**
     * @notice burns an existing debt position token.
     * @dev only valid callers are allowedMinters
     * @param tnftId unique id of a TNFT to burn
     */
    function burn(uint256 tnftId) public onlyMinters(msg.sender) {
        _burn(tnftId);
    }

    /**
     * @notice checks if a loan is overdue
     * @param tnftId unique id of a TNFT to check overdue status
     */
    function isOverDue(uint256 tnftId) public view returns (bool) {
        return
            block.timestamp >
            idToNFT[tnftId].createdAt +
                (1 days * idToNFT[tnftId].termDays) +
                (1 days * graceDays);
    }

    /**
     * @notice checks the current auction price of a foreclosable loan
     * @dev throws error if loan is not overdue
     * @param tnftId unique id of a TNFT to get current auction price
     */
    function getLiveAuctionPrice(uint256 tnftId) public view returns (uint256) {
        require(isOverDue(tnftId), "Loan unavailable for foreclosure");

        uint256 timeElapsedDays = (block.timestamp -
            (idToNFT[tnftId].createdAt + (1 days * idToNFT[tnftId].termDays))) /
            86400;

        uint256 initialAuctionPrice = ((idToNFT[tnftId].principal +
            idToNFT[tnftId].fee) * auctionStartingMultiplierPercent) / 100;
        return
            initialAuctionPrice -
            ((initialAuctionPrice *
                auctionDiscountFactorPercent *
                timeElapsedDays) / 100);
    }

    /**
     * @notice Getter function for graceDays
     */
    function getGraceDays() public view returns (uint8) {
        return graceDays;
    }

    /**
     * @notice Getter function for auctionStartingMultiplierPercent
     */
    function getAuctionStartingMultiplierPercent()
        public
        view
        returns (uint16)
    {
        return auctionStartingMultiplierPercent;
    }

    /**
     * @notice Getter function for auctionDiscountFactorPercent
     */
    function getAuctionDiscountFactorPercent() public view returns (uint16) {
        return auctionDiscountFactorPercent;
    }

    /**
     * @notice Calculates total amount owed to a market (principal + fee) for a given debt position
     * @param tnftId unique TNFT ID of the debt position
     * @return total amount owed
     */
    function getBalanceDue(uint256 tnftId) public view returns (uint256) {
        return idToNFT[tnftId].principal + idToNFT[tnftId].fee;
    }

    /**
     * @notice Returns timestamp of when the amount is due for a given debt position
     * @param tnftId unique TNFT ID of the debt position
     * @return unix timestamp of due date
     */
    function getDueDate(uint256 tnftId) public view returns (uint256) {
        return idToNFT[tnftId].createdAt + (1 days * idToNFT[tnftId].termDays);
    }

    /**
     * @notice principal on a given debt position
     * @param tnftId unique TNFT ID of the debt position
     * @return principal value
     */
    function getPrincipal(uint256 tnftId) public view returns (uint256) {
        return idToNFT[tnftId].principal;
    }

    /**
     * @notice total fee (interest) on a given debt position
     * @param tnftId unique TNFT ID of the debt position
     * @return fee value
     */
    function getFee(uint256 tnftId) public view returns (uint256) {
        return idToNFT[tnftId].fee;
    }

    /**
     * @notice collection address of collateral NFT on a given debt position
     * @param tnftId unique TNFT ID of the debt position
     * @return collection address of collateral NFT
     */
    function getCollectionAddress(uint256 tnftId)
        public
        view
        returns (address)
    {
        return idToNFT[tnftId].collectionAddress;
    }

    /**
     * @notice token ID collateral NFT on a given debt position
     * @param tnftId unique TNFT ID of the debt position
     * @return token ID of collateral NFT
     */
    function getCollectionTokenId(uint256 tnftId)
        public
        view
        returns (uint256)
    {
        return idToNFT[tnftId].collectionTokenId;
    }

    /**
     * @notice loan term (in days) of a given debt position
     * @param tnftId unique TNFT ID of the debt position
     * @return loan term (in days)
     */
    function getTermDays(uint256 tnftId) public view returns (uint256) {
        return idToNFT[tnftId].termDays;
    }

    /**
     * @notice Admin setter function for auctionDiscountFactorPercent
     
     */
    function _setAuctionDiscountFactorPercent(uint8 _newVal)
        external
        onlyOwner
    {
        auctionDiscountFactorPercent = _newVal;
    }

    /**
     * @notice Admin setter function for auctionStartingMultiplierPercent
     */
    function _setAuctionStartingMultiplierPercent(uint16 _newVal)
        external
        onlyOwner
    {
        auctionStartingMultiplierPercent = _newVal;
    }

    /**
     * @notice Admin setter function for graceDays
     */
    function _setGraceDays(uint8 _newVal) external onlyOwner {
        graceDays = _newVal;
    }

    /**
     * @notice Admin function to toggle permissions of an address to include/exclude from allowedMinter
     * @param minter address of allowedMinter
     * @param allowed new toggle value
     */
    function _setAllowedMinter(address minter, bool allowed) public onlyOwner {
        allowedMinters[minter] = allowed;
    }

    /** 
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() override internal view virtual returns (string memory) {
        return baseURI;
    }

}