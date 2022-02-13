// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./ISplitterContract.sol";

contract RKMarket is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Lot structure
    struct Lot {
        address nft;
        uint256 tokenId;
        uint256 price;
        address seller;
        bool isPrimary;
        bool isSold;
        bool isDelisted;
    }

    /// @notice Offer structure
    struct Offer {
        address nft;
        uint256 tokenId;
        uint256 price;
        address buyer;
        bool isAccepted;
        bool isCancelled;
        uint256 expireAt;
    }

    /// @notice Array of lots
    Lot[] public lots;

    /// @notice Array of offers
    Offer[] public offers;

    /// @notice Contract admin (not owner)
    address payable public admin;

    /// @notice Address of the Splitter Contract
    address public splitter;

    /// @notice Address of the wrapped Ethereum
    address public weth;

    /// @notice Amount to pay for secondary listing
    uint256 public listingPrice;

    /// @notice Get artist address by NFT address and token ID
    mapping(address => mapping(uint256 => address)) public artists;

    /// @notice Get artist address by NFT address
    mapping(address => address) public artistOfCollection;

    /**
     * @notice Events
     */
    event AdminChanged(address oldAdmin, address newAdmin);
    event WethChanged(address oldWeth, address newWeth);
    event SplitterChanged(address oldSplitter, address newSplitter);
    event ListingPriceChanged(uint256 oldPrice, uint256 newPrice);
    event NewLot(
        uint256 lotId,
        address nft,
        uint256 tokenId,
        uint256 price,
        address seller,
        bool isPrimary,
        bool isSold,
        bool isDelisted
    );
    event NewOffer(
        uint256 offerId,
        address nft,
        uint256 tokenId,
        uint256 price,
        address buyer,
        bool isAccepted,
        bool isCancelled,
        uint256 expireAt
    );
    event Delisted(uint256 lotId);
    event OfferCanceled(uint256 offerId);
    event Sold(
        address nft,
        uint256 tokenId,
        uint256 price,
        address seller,
        address artist,
        bool isPrimarySale
    );

    /**
     * @notice Restrict access for admin address only
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    /**
     * @notice Restrict if splitter address is not set yet
     */
    modifier splitterExist() {
        require(splitter != address(0), "set splitter contract first");
        _;
    }

    /// @notice Acts like constructor() for upgradeable contracts
    function initialize(address payable _admin, address _weth)
        external
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        require(_admin != address(0), "zero address");
        require(_weth != address(0), "zero address");
        admin = _admin;
        weth = _weth;
        listingPrice = 1 ether;
    }

    /**
     * @notice Get filtered lots
     * @param from - Minimal lotId
     * @param to - Get to lot Id. 0 ar any value greater than lots.length will set "to" to lots.length
     * @param getActive - Is get active lots?
     * @param getSold - Is get sold lots?
     * @param getDelisted - Is get canceled lots?
     * @return _filteredLots - Array of filtered lots
     */
    function getLots(
        uint256 from,
        uint256 to,
        bool getActive,
        bool getSold,
        bool getDelisted
    ) external view returns (Lot[] memory _filteredLots) {
        require(from < lots.length, "value is bigger than lots count");
        if (to == 0 || to >= lots.length) to = lots.length - 1;
        Lot[] memory _tempLots = new Lot[](lots.length);
        uint256 _count = 0;
        for (uint256 i = from; i <= to; i++) {
            if (
                (getActive && (!lots[i].isSold && !lots[i].isDelisted)) ||
                (getSold && lots[i].isSold) ||
                (getDelisted && lots[i].isDelisted)
            ) {
                _tempLots[_count] = lots[i];
                _count++;
            }
        }
        _filteredLots = new Lot[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _filteredLots[i] = _tempLots[i];
        }
    }

    /**
     * @notice Set admin address
     * @param newAdmin - Address of new admin
     */
    function setAdmin(address payable newAdmin) external onlyOwner {
        require(newAdmin != address(0), "zero address");
        require(newAdmin != admin, "same address");
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    /**
     * @notice Set splitter address
     * @param newSplitter - Address of the Splitter Contract
     */
    function setSplitter(address newSplitter) external onlyOwner {
        require(newSplitter != address(0), "zero address");
        require(newSplitter != splitter, "same address");
        emit SplitterChanged(splitter, newSplitter);
        splitter = newSplitter;
    }

    /**
     * @notice Set weth address
     * @param _weth - Address of the weth Contract
     */
    function setWeth(address _weth) external onlyOwner {
        require(_weth != address(0), "zero address");
        require(_weth != weth, "same address");
        emit WethChanged(weth, _weth);
        weth = _weth;
    }

    /**
     * @notice Set price for the listing
     * @param newListingPrice - Amount to spend for listing
     */
    function setListingPrice(uint256 newListingPrice) external onlyOwner {
        require(newListingPrice > 0, "zero amount");
        require(newListingPrice != listingPrice, "same amount");
        emit ListingPriceChanged(listingPrice, newListingPrice);
        listingPrice = newListingPrice;
    }

    /**
     * @notice Set artist address for secondary sale (only for external NFT's)
     * @param artist - Address of artist to distribute funds
     * @param nft - Address of related to artist NFT token
     * @param tokenId - ID of the token
     */
    function setArtist(
        address artist,
        address nft,
        uint256 tokenId
    ) external onlyAdmin {
        require(nft != address(0), "zero address");
        artists[nft][tokenId] = artist;
    }

    /**
     * @notice Set artist address for entire collection (only for external NFT's)
     * @param artist - Address of artist to distribute funds
     * @param nft - Address of related to artist NFT token
     */
    function setArtistForCollection(address artist, address nft)
        external
        onlyAdmin
    {
        require(nft != address(0), "zero address");
        artistOfCollection[nft] = artist;
    }

    /**
     * @notice Set batch of artist addresses for secondary sale (only for external NFT's)
     * @param artist - Address of artist to distribute funds
     * @param nft - Address of related to artist NFT token
     * @param tokenIds - Array of token IDs
     */
    function setArtistBatches(
        address artist,
        address nft,
        uint256[] memory tokenIds
    ) external onlyAdmin {
        require(nft != address(0), "zero address");
        require(tokenIds.length > 0, "empty array");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            artists[nft][tokenIds[i]] = artist;
        }
    }

    /**
     * @notice Returns array of active users lots
     * @param seller - Address of NFT seller
     */
    function lotsOfSeller(address seller)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256 sellerLotsCount = 0;
        for (uint256 i = 0; i < lots.length; i++) {
            if (
                lots[i].seller == seller &&
                !lots[i].isSold &&
                !lots[i].isDelisted
            ) {
                sellerLotsCount++;
            }
        }
        ids = new uint256[](sellerLotsCount);
        uint256 j = 0;
        for (uint256 i = 0; i < lots.length; i++) {
            if (
                lots[i].seller == seller &&
                !lots[i].isSold &&
                !lots[i].isDelisted
            ) {
                ids[j] = i;
                j++;
            }
        }
    }

    /**
     * @notice Returns array of active lots
     */
    function allActiveLots() external view returns (uint256[] memory ids) {
        uint256 lotsCount = 0;
        for (uint256 i = 0; i < lots.length; i++) {
            if (!lots[i].isSold && !lots[i].isDelisted) {
                lotsCount++;
            }
        }
        ids = new uint256[](lotsCount);
        uint256 j = 0;
        for (uint256 i = 0; i < lots.length; i++) {
            if (!lots[i].isSold && !lots[i].isDelisted) {
                ids[j] = i;
                j++;
            }
        }
    }

    /**
     * @notice Admin function for primary sale listing
     * @param nft NFT address
     * @param tokenId Token id
     * @param price NFT price in wei
     * @param artist Address of the artist (for the royalties)
     */
    function primarySale(
        address nft,
        uint256 tokenId,
        uint256 price,
        address artist
    ) external onlyAdmin splitterExist {
        artists[nft][tokenId] = artist;
        _createSale(nft, tokenId, price, true);
    }

    /**
     * @notice Admin function for primary sale batches listing
     */
    function primarySaleBatches(
        address nft,
        uint256[] memory tokenIds,
        uint256[] memory prices,
        address[] memory _artists
    ) external onlyAdmin splitterExist {
        require(tokenIds.length == prices.length, "should be the same length");
        require(tokenIds.length > 0, "nothing to sale");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            artists[nft][tokenIds[i]] = _artists[i];
            _createSale(nft, tokenIds[i], prices[i], true);
        }
    }

    /**
     * @notice Function for secondary sale listing
     * @param nft NFT address
     * @param tokenId Token id
     * @param price NFT price in wei
     */
    function secondarySale(
        address nft,
        uint256 tokenId,
        uint256 price
    ) external payable splitterExist nonReentrant {
        require(
            artists[nft][tokenId] != address(0) ||
                artistOfCollection[nft] != address(0),
            "add artist first"
        );
        require(msg.value == listingPrice, "wrong amount");
        (bool success, ) = admin.call{value: listingPrice}("");
        require(success, "payment error");
        _createSale(nft, tokenId, price, false);
    }

    function _createSale(
        address nft,
        uint256 tokenId,
        uint256 price,
        bool isPrimary
    ) internal {
        require(nft != address(0), "zero address");
        require(price > 0, "zero amount");
        IERC721Upgradeable(nft).transferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        Lot memory _lot = Lot(
            nft,
            tokenId,
            price,
            msg.sender,
            isPrimary,
            false,
            false
        );
        lots.push(_lot);
        uint256 _id = lots.length - 1;
        emit NewLot(
            _id,
            nft,
            tokenId,
            price,
            msg.sender,
            isPrimary,
            false,
            false
        );
    }

    /**
     * @notice Function for primary sale delisting
     * @param lotId ID of lot (possition in lots array)
     */
    function delist(uint256 lotId) external onlyAdmin {
        _delist(lotId);
    }

    /**
     * @notice Function for primary sale batches delisting
     * @param lotIds ID of lot (possition in lots array)
     */
    function delistBatches(uint256[] memory lotIds) external onlyAdmin {
        require(lotIds.length > 0, "no ids provided");
        for (uint256 i = 0; i < lotIds.length; i++) {
            _delist(i);
        }
    }

    /**
     * @notice Function for secondary sale delisting
     * @param lotId ID of lot (possition in lots array)
     */
    function delistSecondary(uint256 lotId) external {
        Lot memory _lot = lots[lotId];
        require(!_lot.isPrimary, "only for aftermarket lots");
        require(
            msg.sender == _lot.seller || msg.sender == admin,
            "only admin and seller can delist"
        );
        _delist(lotId);
    }

    function _delist(uint256 lotId) internal {
        Lot storage _lot = lots[lotId];
        _lot.isDelisted = true;
        IERC721Upgradeable(_lot.nft).transferFrom(
            address(this),
            _lot.seller,
            _lot.tokenId
        );
        emit Delisted(lotId);
    }

    /**
     * @notice Buy NFT using specified lot ID
     * @param lotId ID of lot (possition in lots array)
     */
    function buy(uint256 lotId) external splitterExist nonReentrant {
        Lot storage _lot = lots[lotId];
        require(!_lot.isSold, "already sold");
        require(!_lot.isDelisted, "lot delisted");
        require(
            artists[_lot.nft][_lot.tokenId] != address(0) ||
                artistOfCollection[_lot.nft] != address(0),
            "add artist first"
        );
        address _artist;
        if (artists[_lot.nft][_lot.tokenId] != address(0)) {
            _artist = artists[_lot.nft][_lot.tokenId];
        } else {
            _artist = artistOfCollection[_lot.nft];
        }
        if (_lot.isPrimary) {
            (
                address[] memory addresses,
                uint256[] memory shares
            ) = ISplitterContract(splitter).getPrimaryDistribution(_artist);
            require(addresses.length == shares.length, "arrays not equal");
            require(addresses.length > 0, "arrays are empty");
        } else {
            (
                address[] memory addresses,
                uint256[] memory shares
            ) = ISplitterContract(splitter).getSecondaryDistribution(_artist);
            require(addresses.length == shares.length, "arrays not equal");
            require(addresses.length > 0, "arrays are empty");
        }
        IERC20Upgradeable(weth).safeTransferFrom(
            msg.sender,
            splitter,
            _lot.price
        );
        if (_lot.isPrimary) {
            ISplitterContract(splitter).primaryDistribution(
                _artist,
                _lot.price
            );
        } else {
            ISplitterContract(splitter).secondaryDistribution(
                _artist,
                _lot.seller,
                _lot.price
            );
        }
        _lot.isSold = true;
        IERC721Upgradeable(_lot.nft).transferFrom(
            address(this),
            msg.sender,
            _lot.tokenId
        );
        emit Sold(
            _lot.nft,
            _lot.tokenId,
            _lot.price,
            _lot.seller,
            _artist,
            _lot.isPrimary
        );
    }

    /**
     * @notice Create offer instance
     */
    function makeOffer(
        address nft,
        uint256 tokenId,
        uint256 price,
        uint256 duration
    ) external returns (uint256 id) {
        Offer memory offer = Offer(
            nft,
            tokenId,
            price,
            msg.sender,
            false,
            false,
            block.timestamp + duration
        );
        offers.push(offer);
        id = offers.length - 1;
        emit NewOffer(
            id,
            nft,
            tokenId,
            price,
            msg.sender,
            false,
            false,
            block.timestamp + duration
        );
    }

    function cancelOffer(uint256 offerId) external {
        Offer storage _offer = offers[offerId];
        _offer.isCancelled = true;
        emit OfferCanceled(offerId);
    }

    function acceptOffer(uint256 offerId) external nonReentrant {
        Offer storage _offer = offers[offerId];
        require(!_offer.isAccepted, "Offer already accepted!");
        require(!_offer.isCancelled, "Offer already canceled!");
        require(block.timestamp < _offer.expireAt, "Offer was expired!");
        require(
            artists[_offer.nft][_offer.tokenId] != address(0) ||
                artistOfCollection[_offer.nft] != address(0),
            "add artist first"
        );
        address _artist;
        if (artists[_offer.nft][_offer.tokenId] != address(0)) {
            _artist = artists[_offer.nft][_offer.tokenId];
        } else {
            _artist = artistOfCollection[_offer.nft];
        }
        _offer.isAccepted = true;
        // Unlisted NFT
        if (
            IERC721Upgradeable(_offer.nft).ownerOf(_offer.tokenId) == msg.sender
        ) {
            //approve required
            _executeOffer(
                msg.sender,
                _offer.buyer,
                _offer.nft,
                _offer.tokenId,
                _offer.price,
                _artist
            );
        }
        // Listed NFT
        if (
            IERC721Upgradeable(_offer.nft).ownerOf(_offer.tokenId) ==
            address(this)
        ) {
            _executeOffer(
                address(this),
                _offer.buyer,
                _offer.nft,
                _offer.tokenId,
                _offer.price,
                _artist
            );
            uint256 lotId = lotIdOfItem(_offer.nft, _offer.tokenId);
            lots[lotId].isSold = true;
        }

        emit Sold(
            _offer.nft,
            _offer.tokenId,
            _offer.price,
            msg.sender,
            _artist,
            false
        );
    }

    function _executeOffer(
        address _holder,
        address _buyer,
        address _nft,
        uint256 _tokenId,
        uint256 _price,
        address _artist
    ) internal {
        IERC721Upgradeable(_nft).safeTransferFrom(_holder, _buyer, _tokenId);
        IERC20Upgradeable(weth).safeTransferFrom(_buyer, splitter, _price);
        ISplitterContract(splitter).secondaryDistribution(
            _artist,
            msg.sender,
            _price
        );
    }

    /**
     * @notice Returns array of buyer offers
     * @param buyer - Address of NFT buyer
     */
    function offersOfBuyer(address buyer)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256 buyerOffersCount = 0;
        for (uint256 i = 0; i < offers.length; i++) {
            if (offers[i].buyer == buyer && isActiveOffer(i)) {
                buyerOffersCount++;
            }
        }
        ids = new uint256[](buyerOffersCount);
        uint256 j = 0;
        for (uint256 i = 0; i < offers.length; i++) {
            if (offers[i].buyer == buyer && isActiveOffer(i)) {
                ids[j] = i;
                j++;
            }
        }
    }

    /**
     * @notice Returns array of irrelevant buyer offers (accepted, expired or canceled)
     * @param buyer - Address of NFT buyer
     */
    function irrelevantOffersOfBuyer(address buyer)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256 buyerOffersCount = 0;
        for (uint256 i = 0; i < offers.length; i++) {
            if (offers[i].buyer == buyer && !isActiveOffer(i)) {
                buyerOffersCount++;
            }
        }
        ids = new uint256[](buyerOffersCount);
        uint256 j = 0;
        for (uint256 i = 0; i < offers.length; i++) {
            if (offers[i].buyer == buyer && !isActiveOffer(i)) {
                ids[j] = i;
                j++;
            }
        }
    }

    /**
     * @notice Returns array of seller offers
     * @param seller - Address of NFT seller
     */
    function offersOfSeller(address seller)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256 totalOffers = 0;
        for (uint256 i = 0; i < offers.length; i++) {
            if (isActiveOffer(i)) {
                if (
                    sellerOfItem(offers[i].nft, offers[i].tokenId) == seller ||
                    IERC721Upgradeable(offers[i].nft).ownerOf(
                        offers[i].tokenId
                    ) ==
                    seller
                ) {
                    totalOffers++;
                }
            }
        }

        ids = new uint256[](totalOffers);
        uint256 j = 0;
        for (uint256 i = 0; i < offers.length; i++) {
            if (isActiveOffer(i)) {
                if (
                    sellerOfItem(offers[i].nft, offers[i].tokenId) == seller ||
                    IERC721Upgradeable(offers[i].nft).ownerOf(
                        offers[i].tokenId
                    ) ==
                    seller
                ) {
                    ids[j] = i;
                    j++;
                }
            }
        }
    }

    /**
     * @notice Returns array of irrelevant seller offers
     * @param seller - Address of NFT seller
     */
    function irrelevantOffersOfSeller(address seller)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256 totalOffers = 0;
        for (uint256 i = 0; i < offers.length; i++) {
            if (!isActiveOffer(i)) {
                if (
                    sellerOfItem(offers[i].nft, offers[i].tokenId) == seller ||
                    IERC721Upgradeable(offers[i].nft).ownerOf(
                        offers[i].tokenId
                    ) ==
                    seller
                ) {
                    totalOffers++;
                }
            }
        }

        ids = new uint256[](totalOffers);
        uint256 j = 0;
        for (uint256 i = 0; i < offers.length; i++) {
            if (!isActiveOffer(i)) {
                if (
                    sellerOfItem(offers[i].nft, offers[i].tokenId) == seller ||
                    IERC721Upgradeable(offers[i].nft).ownerOf(
                        offers[i].tokenId
                    ) ==
                    seller
                ) {
                    ids[j] = i;
                    j++;
                }
            }
        }
    }

    /**
     * @notice Returns seller of token from the market by token info
     */
    function sellerOfItem(address nft, uint256 id)
        public
        view
        returns (address)
    {
        for (uint256 i = 0; i < lots.length; i++) {
            if (
                lots[i].nft == nft &&
                lots[i].tokenId == id &&
                !lots[i].isPrimary &&
                !lots[i].isSold &&
                !lots[i].isDelisted
            ) {
                return lots[i].seller;
            }
        }
    }

    /**
     * @notice Returns lot ID by token info
     */
    function lotIdOfItem(address nft, uint256 id)
        public
        view
        returns (uint256)
    {
        for (uint256 i = 0; i < lots.length; i++) {
            if (
                lots[i].nft == nft &&
                lots[i].tokenId == id &&
                !lots[i].isSold &&
                !lots[i].isDelisted
            ) {
                return i;
            }
        }

        revert("Not found");
    }

    /**
     * @dev Return true if offer is active
     */
    function isActiveOffer(uint256 id) public view returns (bool) {
        if (
            !offers[id].isAccepted &&
            !offers[id].isCancelled &&
            block.timestamp < offers[id].expireAt
        ) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice For stuck tokens rescue only
     */
    function rescueTokens(address _token) external onlyOwner {
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransfer(msg.sender, balance);
    }

    /**
     * @notice For stuck NFT tokens rescue only
     */
    function rescueNFTTokens(address token, uint256 tokenId)
        external
        onlyOwner
    {
        IERC721Upgradeable(token).transferFrom(
            address(this),
            msg.sender,
            tokenId
        );
    }
}