// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Marketplace is
    Initializable,
    IERC721Receiver,
    ContextUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    function initialize() public initializer {
        __Context_init();
        __Ownable_init();
        // remember to use this in mainnet
        // __ReentrancyGuard_init();
    }

    modifier validNFTContractAddress(address _address) {
        require(msg.sender != address(0) && msg.sender != address(this));
        _;
    }

    // Map from token ID to their corresponding offer.
    // map[contractAddress]map[tokenId]Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    address public treasury;
    uint256 public serviceFee;

    event ListingCreated(address indexed owner, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event Unlisted(uint256 indexed tokenId);
    event ListingUpdated(uint256 indexed tokenId, uint256 price);
    event Trade(address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price);

    struct Listing {
        // Price (in wei)
        uint256 price;
        // Current owner of NFT
        address owner;
    }

    function getListing(address nftAddress, uint256 tokenId) external view returns (uint256 price, address owner)
    {
        Listing storage listing = listings[nftAddress][tokenId];
        require(listingExists(listing));
        return (listing.price, listing.owner);
    }

    function createListing(address nftAddress, uint256 tokenId, uint256 price) external validNFTContractAddress(nftAddress) {
        address seller = msg.sender;
        IERC721 nft = getNftContract(nftAddress);
        require(nft.ownerOf(tokenId) == seller, "Marketplace: not an owner");
        require(nftAddress != address(0) && nftAddress != address(this));

        nft.safeTransferFrom(seller, address(this), tokenId);
        // payable(address(this)).transfer(price);

        Listing memory listing = Listing(price, seller);
        listings[nftAddress][tokenId] = listing;

        emit ListingCreated(seller, nftAddress, tokenId, price);
    }

    function cancelListing(address nftAddress, uint256 tokenId) external onlySeller(nftAddress, tokenId) {
        IERC721 nft = getNftContract(nftAddress);
        Listing storage listing = listings[nftAddress][tokenId];
        nft.safeTransferFrom(address(this), listing.owner, tokenId);
        delete listings[nftAddress][tokenId];
        emit Unlisted(tokenId);
    }

    function updateListing(address nftAddress, uint256 tokenId, uint256 _price) external onlySeller(nftAddress, tokenId) {
        // update new listing
        listings[nftAddress][tokenId].price = _price;
        emit ListingUpdated(tokenId, _price);
    }

    function buy(address nftAddress, uint256 tokenId) external payable {
        Listing storage listing = listings[nftAddress][tokenId];
        require(listingExists(listing), "404");
        require(msg.value == listing.price, "P");

        // it is require that we setup the treasury address beforehand
        payable(treasury).transfer(msg.value - msg.value * (100 - serviceFee)/100);
        payable(listing.owner).transfer(msg.value * (100 - serviceFee)/100);

        IERC721 nft = getNftContract(nftAddress);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        delete listings[nftAddress][tokenId];
        emit Trade(msg.sender, listing.owner, nftAddress, tokenId, listing.price);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /// @dev Returns true if the offer is on marketplace.
    /// @param listing - Listing to check.
    function listingExists(Listing storage listing) internal view returns (bool)
    {
        return (listing.owner != address(0));
    }

    /// @dev Gets the NFT object from an address, validating that implementsERC721 is true.
    /// @param nftAddress - Address of the NFT.
    function getNftContract(address nftAddress) internal pure returns (IERC721) {
        IERC721 candidateContract = IERC721(nftAddress);
        return candidateContract;
    }

    modifier onlySeller(address nftAddress, uint256 tokenId) {
        require(listings[nftAddress][tokenId].owner == msg.sender);
        _;
    }

    /// implement for IERC721Receiver
    function onERC721Received(address, address, uint256, bytes memory) external virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}