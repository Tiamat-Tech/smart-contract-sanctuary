// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.0 <0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract DelegateContract is Ownable, IERC721Receiver
{
    address authorizedCaller;
    
    event TransactionCompleted(address _erc20TokenContract, address _erc721TokenContract, address _seller, address _buyer, uint256 _erc20TokenAmount, uint256 _erc721TokenId, uint256 _quantity, PricingType _pricingType);
    event ERC20TransferCompleted(address _erc20TokenContract, address _from, address _to, uint256 _amount);
    event ERC721TransferCompleted(address _erc721TokenContract, address _from, address _to, uint256 _tokenId);
    event ERC1155TransferCompleted(address _erc1155TokenContract, address _from, address _to, uint256 _tokenId, uint256 _quantity, bytes data);
    event BidPlaced(address _erc20TokenAddress, address _nftTokenAddress, address _previousBidder, address _currentBidder, uint256 _previousBid, uint256 _currentBid, uint256 _tokenId, string _userId);
    event OrderCreated(address _erc20TokenAddress, address _nftTokenAddress, uint256 _tokenId, uint256 _quantity, TokenType _tokenType, uint256 _startingBid, address _creator, string _userId, PricingType _paymentMode, uint256 _startTime, uint256 _endTime);
    
    enum TokenType{
        Undefined,
        ERC721,
        ERC1155
    }
    
    enum TransactionType
    {
        Undefined,
        INSTANT_BUY,
        BID
    }
    
    enum PricingType
    {
        Undefined,
        INSTANT_BUY,
        TIMED_AUCTION,
        UNLIMITED_AUCTION
    }
    
    struct Bid { 
        address highestBidder;
        uint256 highestBid;
        bool isOpen;
        uint256 quantity;
        address erc20TokenAddress;
        address creator;
        PricingType pricingType;
        uint256 startDate;
        uint256 endDate;
        uint256 bidsPlaced;
    }
    

    struct SaleItem {
        address seller;
        uint256 price;
        bool isOpen;
        uint256 quantity;
        address erc20TokenAddress;                                                                                                                
    }
    

    mapping(address => mapping(uint256 => Bid)) public bidDetails ;
   mapping(address => mapping(uint256 => SaleItem)) public instantBuyDetails;
    
   constructor(address _authorizedCaller) {
        authorizedCaller = _authorizedCaller;
    }
    
   modifier onlyAuthorizedCaller()
   {
        require (msg.sender == authorizedCaller, "Only an authorized address can access functions in this contract");
        _;
    }
    
   function instantBuy(address _nftTokenAddress, TokenType _tokenType, uint256 _tokenId, bytes memory _data) public 
   {
       address _buyer =  msg.sender;
       SaleItem memory saleItem = instantBuyDetails[_nftTokenAddress][_tokenId];
       address erc20TokenAddress = saleItem.erc20TokenAddress;
       address seller = saleItem.seller;
       uint256 price = saleItem.price;
       uint256 quantity = saleItem.quantity;

       require(saleItem.isOpen, "Order is not Open. Make sure that the Owner of the token has offered it up for sale");
       transferERC20(erc20TokenAddress, msg.sender, seller, price);
       if(_tokenType == TokenType.ERC721){
            IERC721 _erc721Contract = IERC721(_nftTokenAddress);
            _erc721Contract.setApprovalForAll(address(this), true);
            _erc721Contract.safeTransferFrom(address(this), msg.sender, _tokenId);
            saleItem = SaleItem(address(0), 0, false, 0, address(0));
            instantBuyDetails[_nftTokenAddress][_tokenId] = saleItem;
            emit TransactionCompleted(erc20TokenAddress, _nftTokenAddress, seller, msg.sender, price, _tokenId, 1, PricingType.INSTANT_BUY);
       }
       else if(_tokenType == TokenType.ERC1155)
       {
            IERC1155 _erc1155Contract = IERC1155(_nftTokenAddress);
            _erc1155Contract.safeTransferFrom(saleItem.seller, msg.sender, _tokenId, saleItem.quantity, _data);
            saleItem = SaleItem(address(0), 0, false, 0, address(0));
            instantBuyDetails[_nftTokenAddress][_tokenId] = saleItem;
           emit TransactionCompleted(erc20TokenAddress, _nftTokenAddress, seller, msg.sender, price, _tokenId, quantity, PricingType.INSTANT_BUY);
       }
       else{
           revert("NFT Token Type must be specified");
       }
   }
   
   function transferERC20(address _erc20TokenContract, address _from, address _to, uint256 _amount) public 
   {
       require(msg.sender == _from || msg.sender == authorizedCaller, "Not authorized");
       IERC20 _erc20Contract = IERC20(_erc20TokenContract);
       _erc20Contract.transferFrom(_from, _to, _amount);
       emit ERC20TransferCompleted(_erc20TokenContract, _from, _to, _amount);
   }
   
   function transferERC721(address _erc721TokenContract, address _from, address _to, uint256 _tokenId) public 
   {
       require(msg.sender == _from || msg.sender == authorizedCaller, "Not authorized");
       IERC721 _erc721Contract = IERC721(_erc721TokenContract);
       _erc721Contract.safeTransferFrom(_from, _to, _tokenId);
       emit ERC721TransferCompleted(_erc721TokenContract, _from, _to, _tokenId);
   }
   
   function transferERC1155(address _erc1155TokenContract, address _from, address _to, uint256 _tokenId, uint256 _quantity, bytes memory _data) public 
   {
       require(msg.sender == _from || msg.sender == authorizedCaller, "Not authorized");
       IERC1155 _erc1155Contract = IERC1155(_erc1155TokenContract);
       _erc1155Contract.safeTransferFrom(_from, _to, _tokenId, _quantity, _data);
       emit ERC1155TransferCompleted(_erc1155TokenContract, _from, _to, _tokenId, _quantity, _data);
   }
   
   function OfferForSale(address _erc20TokenAddress, address _nftTokenAddress, uint256 _tokenId, uint256 _quantity, TokenType _tokenType, uint256 _startingPrice, string memory _userId, PricingType _pricingType, uint256 _startTime, uint256 _endTime) public
   {
       Bid memory bid = bidDetails[_nftTokenAddress][_tokenId];
       SaleItem memory saleItem = instantBuyDetails[_nftTokenAddress][_tokenId];

       require(!bid.isOpen && !saleItem.isOpen, "Bid for the token is currently active");

       if(_tokenType == TokenType.ERC721)
       {
           IERC721 erc721TokenContract = IERC721(_nftTokenAddress);
           require(erc721TokenContract.ownerOf(_tokenId) == msg.sender, "Bid Creator must be Owner of token");
           transferERC721(_nftTokenAddress, msg.sender, address(this), _tokenId);
           bid.quantity = 1;
       }else if(_tokenType == TokenType.ERC1155)
       {
           IERC1155 erc1155TokenContract = IERC1155(_nftTokenAddress);
           require(erc1155TokenContract.balanceOf(msg.sender, _tokenId) >= _quantity, "Quantity of tokens to bid exceeds balance");
           bid.quantity = _quantity;
           
       }else{
           revert("Token type is not valid. Must be ERC721 Or ERC1155");
       }
       
       if(_pricingType == PricingType.UNLIMITED_AUCTION || _pricingType == PricingType.TIMED_AUCTION){
           
           bid.erc20TokenAddress = _erc20TokenAddress;
            bid.creator = msg.sender;
            bid.highestBid = _startingPrice;
            bid.isOpen = true;
            bid.pricingType = _pricingType;
            bid.startDate = _startTime;
            bid.endDate = _endTime;
            bidDetails[_nftTokenAddress][_tokenId] = bid;

       }else if(_pricingType == PricingType.INSTANT_BUY)
       {
           saleItem.price = _startingPrice;
           saleItem.seller = msg.sender;
           saleItem.quantity = _quantity;
           saleItem.erc20TokenAddress = _erc20TokenAddress;
           saleItem.isOpen = true;
           instantBuyDetails[_nftTokenAddress][_tokenId] = saleItem;
       }else
       {
            revert("Pricing type must either be an auction or instant buy.");
       }
      
      emit OrderCreated( _erc20TokenAddress,  _nftTokenAddress,  _tokenId,  _quantity,  _tokenType,  _startingPrice,  msg.sender,  _userId,  _pricingType, _startTime, _endTime);
   }
   
   function placeBid(address _nftTokenAddress, uint256 _currentBid, uint256  _tokenId, string memory _userId) public 
   {
       Bid memory bid = bidDetails[_nftTokenAddress][_tokenId];
       address _previousBidder = bid.highestBidder;
       uint256 _previousBid = bid.highestBid;
        require(_currentBid > bid.highestBid, "current bid must Me more than previous bid");
       
       IERC20 erc20Contract = IERC20(bid.erc20TokenAddress);
       erc20Contract.transferFrom(msg.sender, address(this), _currentBid);

       if(_previousBidder != address(0))
       {
           erc20Contract.transfer(_previousBidder, _previousBid);
       }
       bid.highestBidder = msg.sender;
       bid.highestBid = _currentBid;
       bid.bidsPlaced++;
       bidDetails[_nftTokenAddress][_tokenId] = bid;
       emit BidPlaced(bid.erc20TokenAddress, _nftTokenAddress, _previousBidder, msg.sender, _previousBid, _currentBid, _tokenId, _userId);
   }
   
   function closeBid(address _nftTokenAddress, uint256 _tokenId, TokenType _tokenType, bytes memory _data) public 
   {
      Bid memory bid = bidDetails[_nftTokenAddress][_tokenId];
      require(msg.sender == bid.creator || msg.sender == authorizedCaller, "Not authorized caller");
      transferERC20(bid.erc20TokenAddress, address(this), bid.creator, bid.highestBid);
      require(bid.pricingType == PricingType.UNLIMITED_AUCTION || bid.pricingType == PricingType.TIMED_AUCTION, "Must be timed or unlimited auction");
      
      if (_tokenType == TokenType.ERC721)
      {
          IERC721 _erc721Contract = IERC721(_nftTokenAddress);
          _erc721Contract.safeTransferFrom(bid.creator, bid.highestBidder, _tokenId);
      }
      else if (_tokenType == TokenType.ERC1155)
      {
        IERC1155 _erc1155Contract = IERC1155(_nftTokenAddress);
       _erc1155Contract.safeTransferFrom(bid.creator, bid.highestBidder, _tokenId, bid.quantity, _data);
      }else
      {
          revert("Token type must be specified");
      }
      
      bid = Bid(address(0), 0, false, 0, address(0), address(0), PricingType.Undefined, 0, 0, 0);
      emit TransactionCompleted(bid.erc20TokenAddress, _nftTokenAddress, bid.creator, bid.highestBidder, bid.highestBid, _tokenId, bid.quantity, bid.pricingType);
   }
   
   function closeOrder(address _nftTokenAddress, uint256 _tokenId) public
   {
       SaleItem memory saleItem = instantBuyDetails[_nftTokenAddress][_tokenId];
       Bid memory bid = bidDetails[_nftTokenAddress][_tokenId];
       if(bid.isOpen && bid.bidsPlaced > 0)
       {
           revert("Bids have already been placed");
       }
       instantBuyDetails[_nftTokenAddress][_tokenId] = SaleItem(address(0), 0, false, 0, address(0));
       bidDetails[_nftTokenAddress][_tokenId] =Bid(address(0), 0, false, 0, address(0), address(0), PricingType.Undefined, 0, 0, 0);
   }
   
   function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) 
   {
       return this.onERC721Received.selector;
   }



  
   
   
}