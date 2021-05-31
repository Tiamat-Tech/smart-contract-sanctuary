pragma solidity ^0.8.0;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "./NFT.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MARKETPLACE {
    using SafeMath for uint256;

    struct orderDetails {
        uint256 tokenId;
        address buyer;
        address seller;
        uint256 totalPrice;
        uint256 time;
    }
    mapping(address => orderDetails[]) public orderLogs;
    address public contractOwner;
    struct forBids {
        uint256 bidPrice;
        address bidder;
        uint256 tokenid;
    }
    // forBids[] bidsArray;
    mapping(uint256 => forBids[]) public bids;

    struct onSaleItem {
        uint256 tokenId;
        address owner;
        bool sold;
        bool onSale;
        uint256 timeOnsale;
        uint256 price;
    }
    mapping(uint256 => onSaleItem) public saleItems;

    NFT public nft;
    IERC20 public vibe;

    struct onBidItem {
        uint256 tokenId;
        address owner;
        bool sold;
        bool onBid;
        uint256 timeOnBid;
        uint256 timeTillBidComplete;
    }
    mapping(uint256 => onBidItem) public bidItems;

    constructor(address nftCreation, address vibeCreation) {
        nft = NFT(nftCreation);
        vibe = IERC20(vibeCreation);
    }

    event PutTokenOnSale(uint256 tokenId, uint256 price, address tokenOwner);
    event PutTokenOnBid(
        uint256 tokenId,
        uint256 bidCompleteTime,
        address tokenOwner
    );
    event MakeBid(uint256 _bidprice, uint256 _tokenId, address bidder);
    event BuyToken(
        uint256 tokenId,
        address buyer,
        uint256 tokenPrice,
        address tokenOwner,
        orderDetails newOrder
    );
    event OnBidComplete(
        uint256 tokenId,
        address winner,
        uint256 _bidprice,
        address tokenOwner,
        orderDetails newOrder
    );
    event RemoveTokenFromSale(
        uint256 tokenId,
        address tokenOwner,
        bool isOnSale
    );
    event RemoveTokenFromBid(uint256 tokenId, address tokenOwner, bool isOnBid);
    event ChangeSaleTokenStatus(uint256 tokenId, bool isSold);
    event ChangeBidTokenStatus(uint256 tokenId, bool isSold);

    modifier checkTokenOwner(uint256 tokenId) {
        require(
            nft.balanceOf(msg.sender, tokenId) != 0,
            "You donot own the token"
        );
        _;
    }

    modifier saleTokenNotSoldAlready(uint256 tokenId) {
        require(!saleItems[tokenId].sold, "Token is already sold!");
        _;
    }
    modifier bidTokenNotSoldAlready(uint256 tokenId) {
        require(!bidItems[tokenId].sold, "Token is already sold!");
        _;
    }

    //     function getBidsArray()public view returns(forBids[] memory){
    //     return bidsArray;
    // }

    // Get the all order logs for perticualr buyer.
    function viewOrderLogs() external view returns (orderDetails[] memory) {
        uint256 length = orderLogs[msg.sender].length;
        orderDetails[] memory records = new orderDetails[](length);
        for (uint256 i = 0; i < length; i++) {
            orderDetails storage orderDetail = orderLogs[msg.sender][i];
            records[i] = orderDetail;
        }
        return records;
    }

    function removeTokenFromSale(uint256 tokenId) external returns (bool) {
        require(
            nft.balanceOf(msg.sender, tokenId) != 0,
            "You donot own the token"
        );
        saleItems[tokenId].onSale = false;
        emit RemoveTokenFromSale(tokenId, msg.sender, false);
        //from node side =>nft.setApprovalForAll(address(this),false);
        return true;
    }

    function removeTokenFromBid(uint256 tokenId) external returns (bool) {
        require(
            nft.balanceOf(msg.sender, tokenId) != 0,
            "You donot own the token"
        );
        bidItems[tokenId].onBid = false;
        emit RemoveTokenFromBid(tokenId, msg.sender, false);
        //from node side=>nft.setApprovalForAll(address(this),false);
        return true;
    }

    function changeSaleTokenStatus(uint256 tokenId, bool status)
        internal
        saleTokenNotSoldAlready(tokenId)
        returns (bool)
    {
        require(
            nft.balanceOf(msg.sender, tokenId) != 0,
            "You donot own the token so you cannot change the status"
        );
        saleItems[tokenId].sold = status;
        emit ChangeSaleTokenStatus(tokenId, status);
        return true;
    }

    function changeBidTokenStatus(uint256 tokenId, bool status)
        internal
        bidTokenNotSoldAlready(tokenId)
        returns (bool)
    {
        require(
            nft.balanceOf(msg.sender, tokenId) != 0,
            "You donot own the token so you cannot change the status"
        );
        bidItems[tokenId].sold = status;
        emit ChangeBidTokenStatus(tokenId, status);
        return true;
    }

    function putTokenOnSale(uint256 tokenId, uint256 price)
        external
        payable
        checkTokenOwner(tokenId)
        returns (bool)
    {
        require(
            nft.balanceOf(msg.sender, tokenId) != 0,
            "You donot own this token"
        );
        //node side => nft.setApprovalForAll(msg.sender,true);
        onSaleItem memory newItem =
            onSaleItem({
                tokenId: tokenId,
                owner: msg.sender,
                sold: false,
                onSale: true,
                timeOnsale: block.timestamp,
                price: price
            });
        saleItems[tokenId] = newItem;
        emit PutTokenOnSale(tokenId, price, msg.sender);
        return true;
    }

    function putTokenOnBid(uint256 tokenId, uint256 bidCompleteTime)
        external
        payable
        returns (bool)
    {
        require(bidItems[tokenId].onBid == false, "Token is already on bid");
        require(
            nft.balanceOf(msg.sender, tokenId) != 0,
            "You donot own this token"
        );
        //node side => nft.setApprovalForAll(address (this),true);
        onBidItem memory newBidItem =
            onBidItem({
                tokenId: tokenId,
                owner: msg.sender,
                sold: false,
                onBid: true,
                timeOnBid: block.timestamp,
                timeTillBidComplete: bidCompleteTime
            });
        bidItems[tokenId] = newBidItem;
        emit PutTokenOnBid(tokenId, bidCompleteTime, msg.sender);
        return true;
    }

    function checkWinner(uint256 id) internal view returns (forBids memory) {
        uint256 temp;
        uint256 b;
        for (uint256 a = 0; a < bids[id].length; a++) {
            if (bids[id][a].bidPrice > temp) {
                temp = bids[id][a].bidPrice;
                b = a;
            }
        }
        return bids[id][b];
    }

    function makeBid(uint256 _bidprice, uint256 _tokenId) public {
        require(
            block.timestamp < bidItems[_tokenId].timeTillBidComplete,
            "Bidding time is over"
        );
        require(
            nft.balanceOf(msg.sender, _tokenId) == 0,
            "You cannot bid on your own NFT"
        );
        require(vibe.balanceOf(msg.sender) > _bidprice, "Insufficient Balance");
        require(bidItems[_tokenId].timeOnBid != 0, "Token is not buyable!");
        require(!bidItems[_tokenId].sold, "Token is already sold!");
        require(bidItems[_tokenId].onBid == true, "Token is not on Bid!");
        //node side => vibe.approve(address(this),_bidprice);
        forBids memory newBid =
            forBids({
                bidder: msg.sender,
                bidPrice: _bidprice,
                tokenid: _tokenId
            });
        //  bidsArray.push(newBid);
        bids[_tokenId].push(newBid);
        emit MakeBid(_bidprice, _tokenId, msg.sender);
    }

    function onBidComplete(uint256 tokenId)
        external
        bidTokenNotSoldAlready(tokenId)
        returns (orderDetails memory)
    {
        require(
            (block.timestamp - bidItems[tokenId].timeTillBidComplete) >= 0,
            "Bidding time is still running"
        );
        require(bidItems[tokenId].timeOnBid != 0, "Token is not buyable!");
        require(!bidItems[tokenId].sold, "Token is already sold!");
        require(bidItems[tokenId].onBid == true, "Token is not on Bid!");
        require(
            nft.isApprovedForAll(bidItems[tokenId].owner, address(this)),
            "Token is not approved to tranfer!"
        );
        forBids memory tempBIds = checkWinner(tokenId);
        require(
            vibe.allowance(tempBIds.bidder, address(this)) >= tempBIds.bidPrice,
            "Check the vibe token allowance"
        );
        orderDetails memory newOrder =
            orderDetails({
                tokenId: tokenId,
                buyer: tempBIds.bidder,
                seller: bidItems[tokenId].owner,
                totalPrice: tempBIds.bidPrice,
                time: block.timestamp
            });
        orderLogs[tempBIds.bidder].push(newOrder);

        address creator = nft.getCreator(tokenId);
        uint256 royalty = nft.getRoyalty(tokenId, creator);

        uint256 tokenSendToCreator =
            SafeMath.div(SafeMath.mul(tempBIds.bidPrice, royalty), 100);
        uint256 tokenSendToSeller =
            SafeMath.sub(tempBIds.bidPrice, tokenSendToCreator);
        vibe.transferFrom(
            tempBIds.bidder,
            bidItems[tokenId].owner,
            tokenSendToSeller
        );
        vibe.transferFrom(tempBIds.bidder, creator, tokenSendToCreator);

        nft.safeTransferFrom(
            bidItems[tokenId].owner,
            tempBIds.bidder,
            tokenId,
            1,
            ""
        );
        changeBidTokenStatus(tokenId, true);
        emit OnBidComplete(
            tokenId,
            tempBIds.bidder,
            tempBIds.bidPrice,
            bidItems[tokenId].owner,
            newOrder
        );
        return newOrder;
    }

    function buyToken(uint256 tokenId, address buyer)
        external
        saleTokenNotSoldAlready(tokenId)
        returns (orderDetails memory)
    {
        // check wether tokens is in buyable list or not!
        require(saleItems[tokenId].timeOnsale != 0, "Token is not buyable!");

        // onSaleItem storage item = saleItems[tokenId];
        require(!saleItems[tokenId].sold, "Token is already sold!");
        require(saleItems[tokenId].onSale == true, "Token is not on sale!");
        require(
            nft.isApprovedForAll(saleItems[tokenId].owner, address(this)),
            "Token is not approved to tranfer!"
        );

        uint256 allowance = vibe.allowance(buyer, address(this));
        require(
            allowance >= saleItems[tokenId].price,
            "Check the token allowance"
        );
        //node side => vibe.approve(address(this),saleItems[tokenId].price)

        orderDetails memory newOrder =
            orderDetails({
                tokenId: tokenId,
                buyer: buyer,
                seller: saleItems[tokenId].owner,
                totalPrice: saleItems[tokenId].price,
                time: block.timestamp
            });
        orderLogs[buyer].push(newOrder);

        // remove token from saleItems list

        address creator = nft.getCreator(tokenId);
        uint256 royalty = nft.getRoyalty(tokenId, creator);

        uint256 tokenSendToCreator =
            SafeMath.div(SafeMath.mul(saleItems[tokenId].price, royalty), 100);
        uint256 tokenSendToSeller =
            SafeMath.sub(saleItems[tokenId].price, tokenSendToCreator);

        vibe.transferFrom(buyer, saleItems[tokenId].owner, tokenSendToSeller);
        vibe.transferFrom(buyer, creator, tokenSendToCreator);

        nft.safeTransferFrom(saleItems[tokenId].owner, buyer, tokenId, 1, "");
        changeSaleTokenStatus(tokenId, true);
        emit BuyToken(
            tokenId,
            buyer,
            saleItems[tokenId].price,
            saleItems[tokenId].owner,
            newOrder
        );
        return newOrder;
    }
}