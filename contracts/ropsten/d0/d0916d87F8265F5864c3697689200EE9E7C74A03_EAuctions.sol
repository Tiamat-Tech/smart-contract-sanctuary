// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./plugins/TokensHandler.sol";


contract EAuctions is ERC721Holder, ERC1155Holder, Ownable, ReentrancyGuard, TokensHandler {
    uint public id;
    uint public fee = 20;
    enum Status {
        LISTED,
        ONGOING,
        FINISHED,
        CANCELLED
    }
    struct Auction {
        address owner;
        address winner;
        address currency;
        address[] nftAddresses;
        uint[] nftIds;
        uint price;
        uint tax;
        uint32[] nftTypes;
        Status status;
    }
    mapping(uint => Auction) public auctions;
    
    event NewAuction(uint indexed id, Auction auction);
    event Cancellation(uint indexed id, Auction auction);
    event Bid(uint indexed id, Auction auction);
    event Finished(uint id, Auction auction);
    
    function setFee(uint _fee) external onlyOwner {
        require(_fee > 0,"Fee should be greater than 0");
        fee = _fee;
    }

    modifier isAccesible(uint auctionId) {
        require(auctionId < id, "Auction ID it not valid");
        require(auctions[auctionId].owner != address(0), "Sale is no longer accessible");
        _;
    }

    function create(address[] calldata _nftAddresses,uint[] calldata _nftIds,uint32[] calldata _nftTypes,uint _price,uint _tax, address _currency) external {
        require(_price > 0 && _tax > 0 && _tax * 2 < _price, "Input values are not valid");
        require(_nftAddresses.length > 0, "Cannot create an empty auction, please add items");
        
        auctions[id].owner = msg.sender;
        auctions[id].currency = _currency;
        auctions[id].nftAddresses = _nftAddresses;
        auctions[id].nftIds = _nftIds;
        auctions[id].nftTypes = _nftTypes;
        auctions[id].price = _price;
        auctions[id].tax = _tax;
        auctions[id].status = Status.LISTED;
        
        // Transfer items from sender to BAuctions
        transferTokens(msg.sender,address(this),_nftAddresses,_nftIds,_nftTypes);
        
        emit NewAuction(id,auctions[id]);

        ++id;        
    }
    
    function cancel(uint auctionId) external isAccesible(auctionId) nonReentrant {
        require(msg.sender == auctions[auctionId].owner, "You're not the owner of this auction");
        require(auctions[auctionId].status == Status.LISTED || auctions[auctionId].status == Status.ONGOING, "Can no longer cancel this auction");
        
        if ( auctions[auctionId].winner != address(0) ){
            if ( auctions[auctionId].currency != address(0) ){
                require(IERC20(auctions[auctionId].currency).transferFrom(
                    address(this),
                    auctions[auctionId].winner, 
                    auctions[auctionId].price
                ), "Refunding the highest bid in tokens failed");
            }else{
                require(payable(auctions[auctionId].winner).send(auctions[auctionId].price),"Refunding the highest bid in ETH failed");
            }
        }
        
        // Transfer items from BAuctions to owner
        transferTokens(address(this),msg.sender,auctions[auctionId].nftAddresses,auctions[auctionId].nftIds,auctions[auctionId].nftTypes);
        
        auctions[auctionId].status = Status.CANCELLED;
        emit Cancellation(auctionId,auctions[auctionId]);
    }
    
    function bid(uint auctionId) external payable isAccesible(auctionId) nonReentrant {
        require(auctions[auctionId].winner != msg.sender, "You're the highest bid already");
        require(auctions[auctionId].status == Status.LISTED || auctions[auctionId].status == Status.ONGOING, "Can no longer bid for this auction");
        
        if ( auctions[auctionId].currency != address(0) ){
            if ( auctions[auctionId].winner != address(0) )
                require(IERC20(auctions[auctionId].currency).transferFrom(
                    address(this),
                    auctions[auctionId].winner, 
                    auctions[auctionId].price
                ), "Refunding the old highest bid in tokens failed");
            auctions[auctionId].price = auctions[auctionId].price + auctions[auctionId].tax;
            auctions[auctionId].winner = msg.sender;
            require(IERC20(auctions[auctionId].currency).transferFrom(
                msg.sender,
                address(this), 
                auctions[auctionId].price
            ), "Receive the new highest bid in tokens failed");
        }else{
            if ( auctions[auctionId].winner != address(0) )
                require(payable(auctions[auctionId].winner).send(auctions[auctionId].price),"Refunding the highest bid in ETH failed");
            auctions[auctionId].price = auctions[auctionId].price + auctions[auctionId].tax;
            auctions[auctionId].winner = msg.sender;
            require(msg.value >= auctions[auctionId].price,"Quantity of ETH is not enough to place a bid");
        }
        auctions[auctionId].status = Status.ONGOING;
        emit Bid(auctionId,auctions[auctionId]);
    }

    function finish(uint auctionId) external nonReentrant {
        require(auctions[auctionId].status == Status.ONGOING, "Auction cannot be finished");
        require(auctions[auctionId].owner == msg.sender, "You're not the owner of this auction");
        if ( auctions[auctionId].currency != address(0) ){
            require(IERC20(auctions[auctionId].currency).transferFrom(
                address(this),
                auctions[auctionId].owner, 
                auctions[auctionId].price
            ), "Sending auction funds failed");
        }else{
            require(payable(auctions[auctionId].owner).send(auctions[auctionId].price),"Sending auction ETH failed");
        }
        
        // Transfer items from BAuctions to owner
        transferTokens(address(this),auctions[auctionId].winner,auctions[auctionId].nftAddresses,auctions[auctionId].nftIds,auctions[auctionId].nftTypes);
        auctions[auctionId].status = Status.FINISHED;
        
        emit Finished(auctionId,auctions[auctionId]);
    }

}