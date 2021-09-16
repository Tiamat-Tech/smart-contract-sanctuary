//"SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import {Auction3} from "./AuctuionTry3.sol";



/**======================================================================== 
 *                           CONTRACT Royaltis
======================================================================== */

    

/**======================================================================== 
 *                           CONTRACT NFT
======================================================================== */
contract NFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    mapping(address => bool) public excludedList;
    Counters.Counter private _tokenIds;
    address contractAddress;
    address contractAuctionAddress;
    address payable public author;
    address payable public owner;
    // address public txFeeToken;
    address payable public maniacadd;
    uint256 public royalty;
    uint256 public fee;
    uint256 public lastPrice;
    mapping(uint => string) public IPFSURL;
    
    mapping(address => uint) public royaltyForAuthor;
    mapping(address => uint) public royaltyForCollectors;
    mapping(address => uint) public PaytoSellers;
    uint public ManiacStonks;
    
    
    
    constructor(
        address marketplaceAddress,
        address _author,
        // address _txFeeToken,
        uint256 _royalty
    ) ERC721("Maniac", "MNC") {
        
        require(PrecisionNumber(royalty) <= PrecisionNumber(10),"the royalty cant exeded the 10%");
        
        contractAddress = marketplaceAddress;
        author = payable(_author);
        owner = payable (_author);
        // txFeeToken = _txFeeToken;
        maniacadd = payable(address(0x0));
        // excludedList[_author] = true;
        excludedList[maniacadd] = true;
        royalty = _royalty;
        fee = 5;
        lastPrice = 0;
    }

    
    // function withdraw
    
    event withdrawPayment(
        address Author,
        uint amont
        );
    
    function withdrawForAuthor() public
       
        returns (bool)
    {
        require(royaltyForAuthor[msg.sender] > 0 ,"you don't have royaltys as Author");
        uint256 amount = royaltyForAuthor[msg.sender];
        if (amount > 0) {
        royaltyForAuthor[msg.sender] =0;
            if (!payable(msg.sender).send(amount)) {
                royaltyForAuthor[msg.sender] = amount;
                emit withdrawPayment(msg.sender,amount);
            }
        }
        emit withdrawPayment(msg.sender,amount);
        return true;
    }
    
     function withdrawForCollectors() public
       
        returns (bool)
    {
        require(royaltyForCollectors[msg.sender] > 0 ,"you don't have royaltys as Collector");
        uint256 amount = royaltyForCollectors[msg.sender];
        if (amount > 0) {
        royaltyForCollectors[msg.sender] = 0;
            if (!payable(msg.sender).send(amount)) {
                royaltyForCollectors[msg.sender] = amount;
                
            }
        }
        emit withdrawPayment(msg.sender,amount);
        return true;
    }
    
    
     function withdrawForSellers() public
       
        returns (bool)
    {
        require(PaytoSellers[msg.sender] > 0 ,"you don't have royaltys as Seller");
        uint256 amount = PaytoSellers[msg.sender];
        if (amount > 0) {
        PaytoSellers[msg.sender] = 0;
            if (!payable(msg.sender).send(amount)) {
                PaytoSellers[msg.sender] = amount;
                
            }
        }
        emit withdrawPayment(msg.sender,amount);
        return true;
    }
    
    
    function withdrawStonks() public
       
        returns (bool)
    {
        require(msg.sender == maniacadd ,"you don't have royaltys as Maniac");
        uint256 amount = ManiacStonks;
        if (amount > 0) {
           ManiacStonks = 0;
            if (!payable(msg.sender).send(amount)) {
               ManiacStonks = amount;
            }
        }
       emit withdrawPayment(msg.sender,amount);
        return true;
    }
    
    
    
    
    function getMoneyfrom(address _author,address _seller) external payable {
        uint toManiac = calculateFee(msg.value);
        uint toAuthor = calculateRoyalty(msg.value);
        uint toSeller = msg.value - toManiac - toAuthor;
        ManiacStonks += toManiac;
        royaltyForAuthor[_author] += toAuthor;
        PaytoSellers[_seller] += toSeller;
    }
    
    

    //convert to Precision for div exac.
    function PrecisionNumber(uint256 number) private pure returns (uint256) {
        return number * 10e18;
    }

   

    function createToken(string memory tokenURI, string memory _IPFSURL)
        public
        payable
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        setApprovalForAll(contractAddress, true);
        IPFSURL[_tokenIds.current()] = _IPFSURL;
        
        return newItemId;
        
        
    }

    // calculate the royalty and fee for us.
    function calculateRoyalty(uint256 amount) public view returns (uint256) {
        return amount.mul(PrecisionNumber(royalty)).div(PrecisionNumber(100));
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        return amount.mul(PrecisionNumber(fee)).div(PrecisionNumber(100));
    }
    
    function existToken(uint _Token) public view returns (bool) {
        return _Token <= _tokenIds.current();
    }
    
    
    function getlastToken(uint _Token, address solicitand) external view returns(bool) {
        require (ownerOf(_Token) == solicitand,"You are not the owner");
        return  existToken(_Token);
    } 

//     /**=================================================================
//      * TO DO: Complet the overdrive of transferFrom
//      **=================================================================*/

//     function transferFrom(
//         address from,
//         address to,
//         uint256 tokenId
//     ) public override {
//         // require(_isApprovedOrOwner(_msgSender(),tokenId),"Caller is not owner");
        
//         // pay matic to maniac.
//         if(excludedList[from] == false) {
//          _payTxFee(from);
        
//     }
//         //pay to author.
        
        
//         // continiu normaly.
//          _transfer(from, to, tokenId);
//     }
    
    
    
//     // to avoid the payment aplicans on transferFrom method how is unmutable.
//     function _payTxFee(address from) internal {
//     IERC20 token = IERC20(txFeeToken);
//     uint Txfee = calculateFee(msg.value);
//     token.transferFrom(from, maniacadd, Txfee);
//   }
  
//   function safeTransferFrom(
//     address from,
//     address to,
//     uint256 tokenId,
//     bytes memory _data
//   ) public override {
//     require(
//       _isApprovedOrOwner(_msgSender(), tokenId), 
//       'ERC721: transfer caller is not owner nor approved'
//     );
//     if(excludedList[from] == false) {
//       _payTxFee(from);
//     }
//     _safeTransfer(from, to, tokenId, _data);
//   }

}

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

/**===================================================================== 
                     CONTRACT SALE
======================================================================== */
contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        // address payable seller;
        address payable owner;
        address payable author;
        uint256 status; //\ 0 - free \ 1 - OnSale \ 2 - onAuction \
        uint256 price;
        //data Auction
        uint256 highestBid;
        address highestBidder;
        uint256 timestamp;
        uint256 limitDate;
        bool ended;
        uint256 pendingReturnsCounter;
        mapping(address => uint256) pendingReturns;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    //Event
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        uint256 status,
        uint256 timestamp,
        uint256 limitDate
    );

    /**=================================================================
     *  Put a nft cretated in the NFT Contract onSALE
     **=================================================================*/
    function createMarketItem(
        address nftContract,
        uint256 _tokenId,
        uint256 price,
        address author,
        uint256 _status,
        uint256 _limitDate
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        bool eval = NFT(nftContract).getlastToken( _tokenId, msg.sender);
        require(eval , "it dosen't exist");
        
        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId].itemId = itemId;
        idToMarketItem[itemId].nftContract = nftContract;
        idToMarketItem[itemId].tokenId = _tokenId;
        // idToMarketItem[itemId].seller = payable(msg.sender);
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].author = payable(author);
        idToMarketItem[itemId].status = _status;
        idToMarketItem[itemId].price = price;

        if (_status == 2) {
            idToMarketItem[itemId].timestamp = block.timestamp;
            idToMarketItem[itemId].limitDate = block.timestamp + _limitDate;
        }

        IERC721(nftContract).transferFrom(
            msg.sender,
            address(this),
            idToMarketItem[itemId].tokenId
        );

        emit MarketItemCreated(
            itemId,
            nftContract,
            idToMarketItem[itemId].tokenId,
            msg.sender,
            address(0),
            price,
            1,
            block.timestamp,
            _limitDate
        );
    }
        
    function UpdateMarketItem(
        uint itemId,
        uint256 _status,
        address _nftContract,
        uint price,
        uint256 _limitDate
    ) public payable nonReentrant {
        
        require(price > 0, "Price must be at least 1 wei");
         address contractAdd = _nftContract;
        require(idToMarketItem[itemId].owner == msg.sender);
    
        idToMarketItem[itemId].itemId = itemId;
        idToMarketItem[itemId].status = _status;
        idToMarketItem[itemId].price = price;

        if (_status == 2) {
            idToMarketItem[itemId].timestamp = block.timestamp;
            idToMarketItem[itemId].limitDate = block.timestamp + _limitDate;
        }

        IERC721(contractAdd).transferFrom(
            msg.sender,
            address(this),
            idToMarketItem[itemId].tokenId
        );

        emit MarketItemCreated(
            itemId,
            contractAdd,
            idToMarketItem[itemId].tokenId,
            msg.sender,
            address(0),
            price,
            1,
            block.timestamp,
            _limitDate
        );
    }    
    /**=================================================================
     *                    onSALE
     **=================================================================*/

    function Sale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
        ItenOnMarketplace(itemId)
        ItenOnSale(itemId)
    {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        //transfer propierty from contract to buyer
        ERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        ERC721(nftContract).setApprovalForAll(msg.sender, true);
        //transfer from contract to owner
         NFT(nftContract).getMoneyfrom(idToMarketItem[itemId].author,idToMarketItem[itemId].owner);
        // idToMarketItem[itemId].owner.transfer(msg.value);
        idToMarketItem[itemId].owner = payable(msg.sender);
        
        idToMarketItem[itemId].status = 0;
        _itemsSold.increment();
    }

    /*==================================================================
     *    Sale Auction3
     *==================================================================*/
    event HighestBidIncrease(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event AuctionUpdateLimitDate(uint256 itemid, uint256 newlimitDate);

    function bid(uint256 _itemId)
        public
        payable
        ItenOnMarketplace(_itemId)
        ItenOnAuction(_itemId)
    {
        if (block.timestamp > idToMarketItem[_itemId].limitDate) {
            revert("The auction has already ended");
        }

        if (msg.value <= idToMarketItem[_itemId].highestBid) {
            revert("There is already a higher or equal bid");
        }

        if (idToMarketItem[_itemId].highestBid != 0) {
            // set the last bidder as a highestBidder.
            idToMarketItem[_itemId].pendingReturns[
                idToMarketItem[_itemId].highestBidder
            ] += idToMarketItem[_itemId].highestBid;
        }

        idToMarketItem[_itemId].highestBidder = msg.sender;
        idToMarketItem[_itemId].highestBid = msg.value;
        idToMarketItem[_itemId].pendingReturnsCounter++;
        emit HighestBidIncrease(msg.sender, msg.value);
    }

    function witdrawAuctionLosingBidsToUser(uint256 _itemId)
        public
        ItenOnMarketplace(_itemId)
        returns (bool)
    {
        uint256 amount = idToMarketItem[_itemId].pendingReturns[msg.sender];
        if (amount > 0) {
            idToMarketItem[_itemId].pendingReturns[msg.sender] = 0;

            if (!payable(msg.sender).send(amount)) {
                idToMarketItem[_itemId].pendingReturns[msg.sender] = amount;
                idToMarketItem[_itemId].pendingReturnsCounter--;
            }
        }
        return true;
    }

    function auctionEnd(address nftContract, uint256 _itemId)
        public
        ItenOnMarketplace(_itemId)
        ItenOnAuction(_itemId)
    {
        require(
            idToMarketItem[_itemId].owner == msg.sender,
            "you are not allow to call this"
        );

        if (block.timestamp < idToMarketItem[_itemId].limitDate) {
            revert("The auction has not ended yet");
        }

        if (idToMarketItem[_itemId].ended) {
            revert("The function auctionEnded has already been called");
        }

        if (idToMarketItem[_itemId].highestBidder == address(0x0)) {
            IERC721(nftContract).transferFrom(
                address(this),
                msg.sender,
                _itemId
            );
            idToMarketItem[_itemId].status = 0;
            idToMarketItem[_itemId].ended = true;
        } else {
            idToMarketItem[_itemId].ended = true;
            emit AuctionEnded(
                idToMarketItem[_itemId].highestBidder,
                idToMarketItem[_itemId].highestBid
            );
            
            
            NFT(nftContract).getMoneyfrom{value:idToMarketItem[_itemId].highestBid}
            (idToMarketItem[_itemId].author,idToMarketItem[_itemId].owner);
            
            IERC721(nftContract).transferFrom(
                address(this),
                idToMarketItem[_itemId].highestBidder,
                idToMarketItem[_itemId].tokenId
            );
            idToMarketItem[_itemId].owner = payable(
                idToMarketItem[_itemId].highestBidder
            );
            //  address(this).send();
            
        }
    }

    function AddExtraTime(uint256 _itemId, uint256 _newlimitDate)
        public
        ItenOnMarketplace(_itemId)
        ItenOnAuction(_itemId)
    {
        require(
            idToMarketItem[_itemId].owner == msg.sender,
            "you are not the owner of this auction"
        );
        idToMarketItem[_itemId].limitDate = block.timestamp + _newlimitDate;
        emit AuctionUpdateLimitDate(_itemId, _newlimitDate);
    }

    /**=================================================================
     *                        End onSALE
     **=================================================================*/

    /**=================================================================
     *                        other staff
     **=================================================================*/
    struct ItemStatus {
        uint256 status;
        uint256 price;
        uint256 tokenId;
        address actualOwner;
        address authorPubliv;
    }

    function showeStateIten(uint256 _itemId)
        public
        view
        returns (ItemStatus memory)
    {
        uint256 status = idToMarketItem[_itemId].status;
        uint256 price = idToMarketItem[_itemId].price;
        uint256 _tokenId = idToMarketItem[_itemId].tokenId;
        address actualOwner = idToMarketItem[_itemId].owner;
        address authorPubliv = idToMarketItem[_itemId].author;
        ItemStatus memory statusItem = ItemStatus(status, price, _tokenId,actualOwner,authorPubliv);
        return statusItem;
    }
    
     struct ItemAuctionStatus {
        uint256 status;
        uint256 price;
        uint256 tokenId;
        address actualOwner;
        address authorPubliv;
        uint pendingsReturnsAuc;
    }

    function showStatusAuction(uint256 _itemId)
        public
        view
        ItenOnMarketplace(_itemId)
        ItenOnAuction(_itemId)
       
        returns (ItemAuctionStatus memory)
    {
        require(
            idToMarketItem[_itemId].status == 2,
            "this item is not on auction"
        );
         
        uint256 status = idToMarketItem[_itemId].status;
        uint price = idToMarketItem[_itemId].highestBid;
        uint256 tokenId = idToMarketItem[_itemId].tokenId;
        address actualOwner = idToMarketItem[_itemId].owner;
        address authorPubliv = idToMarketItem[_itemId].author;
        uint256 total = idToMarketItem[_itemId].pendingReturnsCounter;
        ItemAuctionStatus memory info = ItemAuctionStatus(
            status,
            price,
            tokenId,
            actualOwner,
            authorPubliv,
            total
            );
        
        return info;
    }

    /**=================================================================
     *                        modifiers
     **=================================================================*/
    modifier ItenOnSale(uint256 _itemId) {
        require(idToMarketItem[_itemId].status == 1, "Item is not On Sale");
        _;
    }

    modifier ItenOnAuction(uint256 _itemId) {
        require(idToMarketItem[_itemId].status == 2, "Item is not On Sale");
        _;
    }

    modifier ItenOnMarketplace(uint256 _itemId) {
        require(
            idToMarketItem[_itemId].tokenId != 0,
            "Item is not On Market place"
        );
        _;
    }
}