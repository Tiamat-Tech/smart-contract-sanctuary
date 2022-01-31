// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./plugins/TokensHandler.sol";


contract ESales is ERC721Holder, ERC1155Holder, Ownable, ReentrancyGuard, TokensHandler {
    uint public id;
    uint public fee = 20;
    enum Status {
        LISTED,
        CANCELLED,
        PURCHASED
    }
    struct Sale {
        address seller;
        address buyer;
        address currency;
        address[] nftAddresses;
        uint[] nftIds;
        uint price;
        uint32[] nftTypes;
        Status status;
    }
    mapping(uint => Sale) public sales;

    event NewSale(uint indexed id, Sale sale);
    event Purchase(uint indexed id, Sale sale);
    event Cancellation(uint indexed id, Sale sale);

    function setFee(uint _fee) external onlyOwner {
        require(_fee > 0,"Fee should be greater than 0");
        fee = _fee;
    }

    modifier isAccesible(uint saleId) {
        require(saleId < id, "Sale ID it not valid");
        require(sales[saleId].seller != address(0), "Sale is no longer accessible");
        _;
    }

    // Creates a sale with one or many items
    function sell(address[] calldata _nftAddresses, uint[] calldata _nftIds, uint32[] calldata _nftTypes, uint _price, address _currency) external {
        require(_price > 0, "Please set a price for the item you want to sell");
        require(_nftAddresses.length > 0, "Cannot create an empty sale, please add items");

        // Transfer the items from sender to BSales smart contract
        transferTokens(msg.sender,address(this),_nftAddresses,_nftIds,_nftTypes);        

        sales[id].nftAddresses = _nftAddresses;
        sales[id].nftIds = _nftIds;
        sales[id].nftTypes = _nftTypes;
        sales[id].price = _price;
        sales[id].currency = _currency;
        sales[id].seller = msg.sender;
        sales[id].status = Status.LISTED;

        // Emits sale creation event
        emit NewSale(id,sales[id]);
        ++id;
    }

    function cancel(uint saleId) external isAccesible(saleId) nonReentrant {
        require(msg.sender == sales[saleId].seller, "You're not the owner of this sale");
        require(sales[saleId].buyer == address(0), "Sell has been completed, not possible to cancel");
        require(sales[saleId].status != Status.CANCELLED, "Sale already cancelled");

        sales[saleId].status = Status.CANCELLED;

        // Transfer the items from sender to BSales smart contract
        transferTokens(address(this),msg.sender,sales[saleId].nftAddresses,sales[saleId].nftIds,sales[saleId].nftTypes);    
        emit Cancellation(saleId,sales[saleId]);
    }

    function buy(uint saleId) external payable isAccesible(saleId) nonReentrant {
        require(sales[saleId].seller != address(0), "Sale is no longer accessible");
        require(sales[saleId].buyer == address(0), "You are too late, sale ended");
        uint bmarketFee = sales[saleId].price / fee;
        if ( sales[saleId].currency != address(0) ){
            require(IERC20(sales[saleId].currency).transferFrom(msg.sender,sales[saleId].seller,sales[saleId].price - bmarketFee), "Transfer of tokens to seller failed");
            require(IERC20(sales[saleId].currency).transferFrom(msg.sender,owner(),bmarketFee), "Transfer of tokens to BMarket failed");
        }else{
            require(msg.value >= sales[saleId].price, "Not enough ETH to buy this item");
            require(payable(msg.sender).send(sales[saleId].price - bmarketFee),"Transfer of ETH to seller failed");
            require(payable(owner()).send(bmarketFee),"Transfer of ETH to BMarket failed");
        }

        // Transfer the items from sender to BSales smart contract
        transferTokens(address(this),msg.sender,sales[saleId].nftAddresses,sales[saleId].nftIds,sales[saleId].nftTypes);

        sales[saleId].status = Status.PURCHASED;
        sales[saleId].buyer = msg.sender;
        
        // Emit the purchase event
        emit Purchase(saleId,sales[saleId]);

    }

}