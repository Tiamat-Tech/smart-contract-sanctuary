// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
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
    }

    modifier validNFTContractAddress(address _address) {
        require(msg.sender != address(0) && msg.sender != address(this));
        _;
    }

    // Map from token ID to their corresponding offer.
    // map[contractAddress]map[tokenId]Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    event ListingCreated(
        address indexed owner,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event Unlisted(uint256 indexed tokenId);
    event ListingUpdated(uint256 indexed tokenId, uint256 price);

    event Trade(
        address indexed buyer,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price
    );

    struct Listing {
        // Price (in wei)
        uint256 price;
        // Current owner of NFT
        address owner;
    }

    /// @dev get listing by _tokenId
    /// @param _nftAddress - address of a deployed contract implementing
    ///  the Nonfungible Interface.
    /// @param _tokenId - ID of token on market.
    function getListing(address _nftAddress, uint256 _tokenId)
        external
        view
        returns (uint256 price, address owner)
    {
        Listing storage _listing = listings[_nftAddress][_tokenId];
        require(_listingExists(_listing));
        return (_listing.price, _listing.owner);
    }

    /// @dev create an listing
    /// @param _nftAddress - address of a deployed contract implementing
    ///  the Nonfungible Interface.
    /// @param _tokenId - ID of nft to market, sender must be owner.
    /// @param _price - price in token for the listing.
    function createListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    ) external validNFTContractAddress(_nftAddress) {
        address _seller = msg.sender;
        IERC721 nft = _getNftContract(_nftAddress);
        require(nft.ownerOf(_tokenId) == _seller, "Marketplace: not an owner");
        require(_nftAddress != address(0) && _nftAddress != address(this));

        nft.safeTransferFrom(_seller, address(this), _tokenId);

        Listing memory _listing = Listing(_price, _seller);
        listings[_nftAddress][_tokenId] = _listing;

        emit ListingCreated(_seller, _nftAddress, _tokenId, _price);
    }

    /// @dev cancel an listing that hasn't accepted yet.
    ///  Returns the NFT to original owner.
    /// @param _nftAddress - address of a deployed contract implementing
    ///  the Nonfungible Interface.
    /// @param _tokenId - ID of nft on market, sender must be owner of the offer.
    function cancelListing(address _nftAddress, uint256 _tokenId) external {
        IERC721 nft = _getNftContract(_nftAddress);
        Listing storage _listing = listings[_nftAddress][_tokenId];
        require(_listingExists(_listing), "Marketplace: offer not exist");
        require(_listing.owner == msg.sender, "Marketplace: not an owner");

        nft.safeTransferFrom(address(this), _listing.owner, _tokenId);

        delete listings[_nftAddress][_tokenId];

        emit Unlisted(_tokenId);
    }

    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    ) external {
        Listing storage _listing = listings[_nftAddress][_tokenId];
        require(_listingExists(_listing), "Marketplace: offer not exist");
        require(_listing.owner == msg.sender, "Marketplace: not an owner");

        // update new listing
        _listing.price = _price;
        listings[_nftAddress][_tokenId] = _listing;

        emit ListingUpdated(_tokenId, _price);
    }

    /// @param _nftAddress - address of a deployed contract implementing
    ///  the Nonfungible Interface.
    /// @param _tokenId - ID of nft on market, offer must exist
    function buy(address _nftAddress, uint256 _tokenId)
        external
        validNFTContractAddress(_nftAddress)
    {
        Listing storage _listing = listings[_nftAddress][_tokenId];
        require(_listingExists(_listing), "Marketplace: offer not exist");

        IERC721 nft = _getNftContract(_nftAddress);
        nft.safeTransferFrom(address(this), msg.sender, _tokenId);

        emit Trade(
            msg.sender,
            _listing.owner,
            _nftAddress,
            _tokenId,
            _listing.price
        );

        delete listings[_nftAddress][_tokenId];
    }

    /// @dev Returns true if the offer is on marketplace.
    /// @param _listing - Listing to check.
    function _listingExists(Listing storage _listing)
        internal
        view
        returns (bool)
    {
        return (_listing.owner != address(0));
    }

    /// @dev Gets the NFT object from an address, validating that implementsERC721 is true.
    /// @param _nftAddress - Address of the NFT.
    function _getNftContract(address _nftAddress)
        internal
        pure
        returns (IERC721)
    {
        IERC721 candidateContract = IERC721(_nftAddress);
        return candidateContract;
    }

    /// implement for IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}