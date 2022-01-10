// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract Marketplace is
    Initializable,
    IERC721Receiver,
    ContextUpgradeable,
    OwnableUpgradeable,
    IERC1155ReceiverUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20Upgradeable for IERC20;
    using SafeMath for uint256;

    function initialize(address _lfwToken) public initializer {
        __Context_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        listingId = 0;
        lfwToken = IERC20(_lfwToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier validNFTContractAddress(address _address) {
        require(_address != address(0) && _address != address(this));
        _;
    }

    // Map from token ID to their corresponding offer.
    // map[contractAddress]map[tokenId]Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    address public treasury;
    //
    uint256 public serviceFee;
    //
    mapping(address => mapping(uint256 => ItemListing)) public itemListings;
    uint256 public listingId;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 public lfwToken;
    mapping(address => mapping(uint256 => bool)) legends;
    mapping(address => bool) whitelistNFTAddress;

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
    event ServiceFeeUpdated(uint256 serviceFee);

    event ItemListingCreated(
        address indexed owner,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        uint256 _listingId
    );
    event ItemUnlisted(uint256 indexed _listingId);
    event ItemListingUpdated(uint256 indexed _listingId, uint256 price);
    event ItemTrade(
        address indexed buyer,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        uint256 _listingId
    );
    struct Listing {
        // Price (in wei)
        uint256 price;
        // Current owner of NFT
        address owner;
    }
    struct ItemListing {
        // Price (in wei)
        uint256 price;
        // Current owner of NFT
        address owner;
        // items
        uint256 tokenId;
        // amount of items
        uint256 amount;
    }

    function getListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (uint256 price, address owner)
    {
        Listing storage listing = listings[nftAddress][tokenId];
        require(listingExists(listing));
        return (listing.price, listing.owner);
    }

    function createListing(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    ) external validNFTContractAddress(nftAddress) {
        address seller = msg.sender;
        require(whitelistNFTAddress[nftAddress], "INVALID_NFT_CONTRACT");
        IERC721 nft = getNftContract(nftAddress);
        require(nft.ownerOf(tokenId) == seller, "Marketplace: not an owner");
        require(msg.sender != address(0) && msg.sender != address(this));

        nft.safeTransferFrom(seller, address(this), tokenId);
        // payable(address(this)).transfer(price);

        Listing memory listing = Listing(price, seller);
        listings[nftAddress][tokenId] = listing;

        emit ListingCreated(seller, nftAddress, tokenId, price);
    }

    function cancelListing(address nftAddress, uint256 tokenId)
        external
        onlySeller(nftAddress, tokenId)
    {
        IERC721 nft = getNftContract(nftAddress);
        Listing storage listing = listings[nftAddress][tokenId];
        nft.safeTransferFrom(address(this), listing.owner, tokenId);
        delete listings[nftAddress][tokenId];
        emit Unlisted(tokenId);
    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 _price
    ) external onlySeller(nftAddress, tokenId) {
        // update new listing
        listings[nftAddress][tokenId].price = _price;
        emit ListingUpdated(tokenId, _price);
    }

    /**
     * @notice
     */
    function buy(
        address nftAddress,
        uint256 tokenId,
        uint256 sellPrice
    ) external payable nonReentrant {
        Listing storage listing = listings[nftAddress][tokenId];
        require(listingExists(listing), "404");

        bool isLegendHero = legends[nftAddress][tokenId];
        if (isLegendHero) {
            require(msg.value == listing.price, "P");
            // it is require that we setup the treasury address beforehand
            if (serviceFee > 0) {
                payable(treasury).transfer(
                    msg.value - (msg.value * (100 - serviceFee)).div(100)
                );
            }

            uint256 price = (msg.value * (100 - serviceFee)).div(100);
            payable(listing.owner).transfer(price);
        } else {
            require(listing.price == sellPrice, "P");
            require(
                lfwToken.transferFrom(
                    msg.sender,
                    payable(treasury),
                    listing.price -
                        (listing.price * (100 - serviceFee)).div(100)
                ) == true,
                "Transfer fee failed"
            );
            uint256 price = (listing.price * (100 - serviceFee)).div(100);
            require(
                lfwToken.transferFrom(
                    msg.sender,
                    payable(listing.owner),
                    price
                ) == true,
                "Transfer failed"
            );
        }

        IERC721 nft = getNftContract(nftAddress);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Trade(
            msg.sender,
            listing.owner,
            nftAddress,
            tokenId,
            listing.price
        );
        delete listings[nftAddress][tokenId];
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0) && _treasury != address(this));
        treasury = _treasury;
    }

    /// @dev Returns true if the offer is on marketplace.
    /// @param listing - Listing to check.
    function listingExists(Listing storage listing)
        internal
        view
        returns (bool)
    {
        return (listing.owner != address(0));
    }

    /// @dev Gets the NFT object from an address, validating that implementsERC721 is true.
    /// @param nftAddress - Address of the NFT.
    function getNftContract(address nftAddress)
        internal
        pure
        returns (IERC721)
    {
        IERC721 candidateContract = IERC721(nftAddress);
        return candidateContract;
    }

    function getNftItemContract(address nftAddress)
        internal
        pure
        returns (ERC1155Upgradeable)
    {
        ERC1155Upgradeable candidateContract = ERC1155Upgradeable(nftAddress);
        return candidateContract;
    }

    modifier onlySeller(address nftAddress, uint256 tokenId) {
        require(listings[nftAddress][tokenId].owner == msg.sender);
        _;
    }
    modifier onlyItemSeller(address nftAddress, uint256 _listingId) {
        require(
            itemListings[nftAddress][_listingId].owner == msg.sender,
            "Marketplace: caller is not owner"
        );
        _;
    }

    function setServiceFee(uint256 _serviceFee) external onlyOwner {
        require(_serviceFee >= 0 && _serviceFee <= 100, "service fee invalid");

        serviceFee = _serviceFee;
        emit ServiceFeeUpdated(serviceFee);
    }

    // function getTreasury() external view returns (address) {
    //     return treasury;
    // }

    /**
     * @dev create listing item in game
     * @param tokenId: list of token id
     * @param amount: list amount of token
     * @param price: list price of token
     */
    function createItemsListing(
        address nftAddress,
        uint256[] memory tokenId,
        uint256[] memory amount,
        uint256[] memory price
    ) external validNFTContractAddress(nftAddress) {
        address seller = msg.sender;
        require(
            seller != address(0) && seller != address(this),
            "Marketplace: Seller invalid address"
        );
        require(
            tokenId.length == amount.length && price.length == amount.length,
            "Marketplace: token, amount or price not match"
        );
        require(whitelistNFTAddress[nftAddress], "INVALID_NFT_CONTRACT");

        ERC1155Upgradeable nftContract = getNftItemContract(nftAddress);

        for (uint256 i = 0; i < tokenId.length; i++) {
            require(amount[i] > 0, "Marketplace: item amount invalid");
            uint256 balances = nftContract.balanceOf(seller, tokenId[i]);
            require(
                balances >= amount[i],
                "Marketplace: item balance insufficient"
            );
        }

        nftContract.safeBatchTransferFrom(
            seller,
            address(this),
            tokenId,
            amount,
            ""
        );

        for (uint256 i = 0; i < tokenId.length; i++) {
            ItemListing memory listing = ItemListing(
                price[i],
                seller,
                tokenId[i],
                amount[i]
            );
            listingId = listingId.add(1);
            itemListings[nftAddress][listingId] = listing;
            emit ItemListingCreated(
                seller,
                nftAddress,
                tokenId[i],
                amount[i],
                price[i],
                listingId
            );
        }
    }

    /**
     * @dev remove listing item in game
     * @param nftAddress: address of NFT contract
     * @param _listingId: id of listing
     */
    function cancelItemsListing(address nftAddress, uint256 _listingId)
        external
        onlyItemSeller(nftAddress, _listingId)
    {
        address seller = msg.sender;
        require(
            seller != address(0) && seller != address(this),
            "Marketplace: Seller invalid"
        );

        ERC1155Upgradeable nft = getNftItemContract(nftAddress);
        ItemListing storage listing = itemListings[nftAddress][_listingId];
        require(listing.owner == seller, "Marketplace: caller is not owner");
        nft.safeTransferFrom(
            address(this),
            listing.owner,
            listing.tokenId,
            listing.amount,
            "0x"
        );
        delete itemListings[nftAddress][_listingId];
        emit ItemUnlisted(_listingId);
    }

    /**
     * @dev update listing price
     * @param nftAddress: address of NFT contract
     * @param _listingId: id of listing
     * @param _price: new price
     */
    function updateItemsListing(
        address nftAddress,
        uint256 _listingId,
        uint256 _price
    ) external onlyItemSeller(nftAddress, _listingId) {
        itemListings[nftAddress][_listingId].price = _price;
        emit ItemListingUpdated(_listingId, _price);
    }

    /**
     * @dev make buy item transaction
     * @param nftAddress: address of NFT contract
     * @param _listingId: id of listing
     */
    function buyItems(
        address nftAddress,
        uint256 _listingId,
        uint256 sellPrice
    ) external nonReentrant {
        ItemListing storage listing = itemListings[nftAddress][_listingId];
        require(listing.tokenId > 0, "Marketplace: listing not existed");
        require(listing.owner != msg.sender, "Marketplace: caller is owner");
        require(sellPrice == listing.price, "P");

        if (serviceFee > 0) {
            require(
                lfwToken.transferFrom(
                    msg.sender,
                    payable(treasury),
                    listing.price -
                        (listing.price * (100 - serviceFee)).div(100)
                ) == true,
                "Transfer failed"
            );
        }

        uint256 price = (listing.price * (100 - serviceFee)).div(100);
        require(
            lfwToken.transferFrom(msg.sender, payable(listing.owner), price) ==
                true,
            "Transfer failed"
        );

        ERC1155Upgradeable nft = getNftItemContract(nftAddress);
        nft.safeTransferFrom(
            address(this),
            msg.sender,
            listing.tokenId,
            listing.amount,
            "0x"
        );

        emit ItemTrade(
            msg.sender,
            listing.owner,
            nftAddress,
            listing.tokenId,
            listing.amount,
            listing.price,
            _listingId
        );
        delete itemListings[nftAddress][_listingId];
    }

    function setLegend(
        uint256[] calldata _heroes,
        bool _isLegend,
        address _nftAddress
    ) external {
        require(_heroes.length > 0, "HERORES_INVALID");
        require(hasRole(OPERATOR_ROLE, _msgSender()), "Caller is not operator");

        if (_nftAddress != address(0)) {
            for (uint256 i = 0; i < _heroes.length; i++) {
                legends[_nftAddress][_heroes[i]] = _isLegend;
            }
        } else {
            for (uint256 i = 0; i < _heroes.length; i++) {
                legends[_msgSender()][_heroes[i]] = _isLegend;
            }
        }
    }

    function isLegend(address _nftAddress, uint256 _tokenId)
        public
        view
        returns (bool)
    {
        return legends[_nftAddress][_tokenId];
    }

    function setLFWToken(address _lfwToken) external onlyOwner {
        require(_lfwToken != address(0) && _lfwToken != address(this));
        lfwToken = IERC20(_lfwToken);
    }

    function whitelistNFTContract(address _nftAddress, bool _whitelist)
        external
        onlyOwner
    {
        require(_nftAddress != address(0) && _nftAddress != address(this));
        whitelistNFTAddress[_nftAddress] = _whitelist;
    }

    /**
     * @dev Can only be called by the current owner.
     * @param _wallet grant wallet address
     * @param _role role
     */
    function grantContractRole(string memory _role, address _wallet)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(keccak256(abi.encodePacked(_role)), _wallet);
    }

    /**
     * @dev Can only be called by the current owner.
     * @param _wallet grant wallet address
     * @param _role role
     */
    function revokeContractRole(string memory _role, address _wallet)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(keccak256(abi.encodePacked(_role)), _wallet);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes memory
    ) external virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlEnumerableUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return this.supportsInterface(interfaceId);
    }
}