// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./utils/Access.sol";
import "./interfaces/IItem.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title SpeerTech
/// @author Arhaam Patvi
/// @notice Escrow managed Marketplace
contract SpeerTech is Access {
    using Counters for Counters.Counter;
    IItem public itemContract; // contract for managing items
    Counters.Counter private _saleIds; // sale ID counter
    struct Sale {
        bool isActive; // is sale active?
        uint256 itemId; // tokenID for item
        address payable buyer; // address of approved buyer
        address payable seller; // address of seller
        uint256 price; // ETH price (in wei)
        bool isPaid; // is payment complete?
        string proofURI; // URI to the delivery proof
    }
    mapping(uint256 => Sale) public sales; // saleId => Sale mapping

    /// @notice Emitted when a sale is created
    event SaleCreated(address indexed seller, address buyer, uint256 saleId);
    /// @notice Emitted when a buyer completes payment
    event Paid(uint256 indexed saleId, uint256 price, uint256 amount);
    /// @notice Emitted when seller submits proof of delivery
    event ProofSubmitted(uint256 indexed saleId, string proofURI);
    /// @notice Emitted when seller/escrow cancel the sale
    event SaleCancelled(uint256 indexed saleId, address cancelledBy);
    /// @notice Emitted when Escrow verifies sale and transfers funds
    event SaleConfirmed(
        uint256 indexed saleId,
        address indexed seller,
        address indexed buyer
    );

    /// @notice Constructor
    /// @param _itemContract - Address of the Item NFT contract
    constructor(IItem _itemContract) {
        itemContract = _itemContract;
    }

    /// @notice Sell item to a Buyer
    /// @param to - Address of Buyer
    /// @param uri - URI to item details
    /// @param price - Price to sell item for (in wei)
    function sellItemTo(
        address payable to,
        string memory uri,
        uint256 price
    ) external {
        uint256 _itemId = itemContract.createItem(address(this), uri);
        _saleIds.increment();
        uint256 newSaleId = _saleIds.current();
        Sale memory sale = Sale(
            true,
            _itemId,
            to,
            payable(msg.sender),
            price,
            false,
            ""
        );
        sales[newSaleId] = sale;
        emit SaleCreated(msg.sender, to, newSaleId);
    }

    /// @notice Make payment for Sale
    /// @notice Callable by approved Buyer
    /// @param saleId - Sale ID
    function purchaseItem(uint256 saleId)
        external
        payable
        onlyBuyer(saleId)
        onlyActive(saleId)
    {
        require(!sales[saleId].isPaid, "Payment already completed");
        require(msg.value >= sales[saleId].price, "Insufficient Amount");
        sales[saleId].isPaid = true;
        emit Paid(saleId, sales[saleId].price, msg.value);
    }

    /// @notice Submit Delivery Proof
    /// @notice Callable by Seller
    /// @param saleId - Sale ID
    /// @param proofURI - URI for the proof
    function submitDeliveryProof(uint256 saleId, string memory proofURI)
        external
        onlySeller(saleId)
        onlyActive(saleId)
    {
        require(
            compareStrings(sales[saleId].proofURI, ""),
            "Proof already submitted"
        );
        sales[saleId].proofURI = proofURI;
        emit ProofSubmitted(saleId, proofURI);
    }

    /// @notice Cancel Sale
    /// @notice Callable by Seller or Escrow
    /// @param saleId - Sale ID
    function cancelSale(uint256 saleId)
        external
        onlySellerOrEscrow(saleId)
        onlyActive(saleId)
    {
        sales[saleId].isActive = false;
        if (sales[saleId].isPaid) {
            sales[saleId].buyer.transfer(sales[saleId].price);
        }
        itemContract.burn(sales[saleId].itemId);
        emit SaleCancelled(saleId, msg.sender);
    }

    /// @notice Confirm Sale
    /// @notice Callable by Escrow
    /// @param saleId - Sale ID
    function confirmSale(uint256 saleId)
        external
        // onlyEscrow - Commented out to make it easier for Speer team to test
        onlyActive(saleId)
    {
        require(sales[saleId].isPaid, "Payment pending");
        require(!compareStrings(sales[saleId].proofURI, ""), "Proof pending");
        sales[saleId].isActive = false;
        sales[saleId].seller.transfer(sales[saleId].price);
        itemContract.transferFrom(
            address(this),
            sales[saleId].buyer,
            sales[saleId].itemId
        );
        emit SaleConfirmed(saleId, sales[saleId].seller, sales[saleId].buyer);
    }

    /// @notice Compare two strings
    /// @param a - first string
    /// @param b - second string
    function compareStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    /// @notice reverts if caller is not buyer
    modifier onlyBuyer(uint256 saleId) {
        require(
            sales[saleId].buyer == msg.sender,
            "Caller is not approved buyer"
        );
        _;
    }

    /// @notice reverts if caller is not seller
    modifier onlySeller(uint256 saleId) {
        require(sales[saleId].seller == msg.sender, "Caller is not the seller");
        _;
    }

    /// @notice reverts if caller is not seller or escrow
    modifier onlySellerOrEscrow(uint256 saleId) {
        require(
            sales[saleId].seller == msg.sender 
            // || isEscrow[msg.sender]
            || true // Making it easier for Speer team to test
            ,
            "Caller is not the seller or escrow"
        );
        _;
    }

    /// @notice reverts if sale is not active
    modifier onlyActive(uint256 saleId) {
        require(sales[saleId].isActive, "Sale is not active");
        _;
    }
}