// SPDX-License-Identifier: ISC
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./PermissionManagement.sol";
import "./MonumentArtifacts.sol";
import "./Splits.sol";
import "./utils/Payable.sol";
import "./utils/MaxGasPrice.sol";

/// @title NFT Marketplace Contract
/// @author [email protected]
/// @notice In Monument.app context, this contract becomes an Automated Market Maker for the Artifacts minted in the Monument Metaverse
contract Marketplace is Payable, MaxGasPrice, ReentrancyGuard {
  PermissionManagement private permissionManagement;
  using SafeMath for uint;



  constructor (
    address _permissionManagementContractAddress,
    address payable _allowedNFTContractAddress
  )
  Payable(_permissionManagementContractAddress)
  MaxGasPrice(_permissionManagementContractAddress)
  {
    permissionManagement = PermissionManagement(_permissionManagementContractAddress);
    
    allowedNFTContractAddress = _allowedNFTContractAddress;
    allowedNFTContract = MonumentArtifacts(_allowedNFTContractAddress);

    // create a genesis $0 fake internal order that expires in 60 seconds for avoiding blank zero mapping conflict
    _placeOrder(0, 60);
    orders[0].tokenId = 10 ** 18;
  }




  // Manage what NFTs can be bought and sold in the marketplace

  address public allowedNFTContractAddress;
  MonumentArtifacts allowedNFTContract;
  
  function changeAllowedNFTContract(address payable _nftContractAddress) 
    external
    returns(address)
  {
    permissionManagement.adminOnlyMethod(msg.sender);
    allowedNFTContractAddress = _nftContractAddress;
    allowedNFTContract = MonumentArtifacts(_nftContractAddress);
    return _nftContractAddress;
  }




  // Taxes

  uint256 public taxOnEverySaleInPermyriad = 200;

  function changeTaxOnEverySaleInPermyriad(uint256 _taxOnEverySaleInPermyriad) 
    external
    returns(uint256)
  {
    permissionManagement.adminOnlyMethod(msg.sender);
    taxOnEverySaleInPermyriad = _taxOnEverySaleInPermyriad;
    return _taxOnEverySaleInPermyriad;
  }




  // Events

  event EnabledAuction(
    uint256 indexed _tokenId,
    uint256 _basePrice,
    uint256 _auctionExpiryTime,
    address indexed _enabledBy
  );

  event EndedAuction(
    uint256 indexed _tokenId,
    address indexed _endedBy
  );

  event EnabledAutoSell(
    uint256 indexed _tokenId,
    uint256 _price,
    address indexed _enabledBy
  );

  event DisabledAutoSell(
    uint256 indexed _tokenId,
    address indexed _disabledBy
  );

  event OrderPlaced(
    uint256 indexed id,
    address indexed buyer,
    uint256 indexed tokenId,
    uint256 price,
    uint256 expiresAt,
    address placedBy
  );

  event OrderExecuted(
    uint256 indexed id
  );

  event OrderCancelled(
    uint256 indexed id
  );




  // Enable/Disable Autosell, and Auction Management

  mapping(uint256 => uint256) public tokenPrice;

  mapping(uint256 => bool) public tokenAutoSellEnabled;

  mapping(uint256 => bool) public tokenAuctionEnabled;
  mapping(uint256 => uint256) public getTokenAuctionExpiryTime;

  /// @notice Allows Token Owner to List the Token on the Marketplace with Auction Enabled
  /// @param _tokenId ID of the Token to List on the Market with Selling Auto-Enabled
  /// @param _basePrice Minimum Price one must put to Bid in the Auction.
  /// @param _auctionExpiresIn Set an End Time for the Auction
  function enableAuction(
    uint256 _tokenId,
    uint256 _basePrice,
    uint256 _auctionExpiresIn
  ) external returns(uint256, uint256) {
    permissionManagement.adhereToBanMethod(msg.sender);

    require(allowedNFTContract.ownerOf(_tokenId) == msg.sender || allowedNFTContract.getApproved(_tokenId) == msg.sender || permissionManagement.moderators(msg.sender) == true, "You cant enableAutoSell for this token");

    tokenPrice[_tokenId] = _basePrice;
    tokenAutoSellEnabled[_tokenId] = false;

    tokenAuctionEnabled[_tokenId] = true;
    getTokenAuctionExpiryTime[_tokenId] = block.timestamp.add(_auctionExpiresIn);

    emit EnabledAuction(
      _tokenId,
      _basePrice,
      getTokenAuctionExpiryTime[_tokenId],
      msg.sender
    );

    return (_tokenId, _basePrice);
  }

  /// @notice Allows Token Owner or the Auction Winner to Execute the Auction of their Token
  /// @param _tokenId ID of the Token whose Auction to end
  function executeAuction(
    uint256 _tokenId
  ) validGasPrice nonReentrant external returns(uint256, uint256) {
    permissionManagement.adhereToBanMethod(msg.sender);

    // cant execute an auction that never started
    require(tokenAuctionEnabled[_tokenId] == true, "Token not auctioned");

    // if auction didn't end by time yet
    if (block.timestamp <= getTokenAuctionExpiryTime[_tokenId]) {
      // allow only moderators or owner or approved to execute the auction
      require(
        permissionManagement.moderators(msg.sender) == true || 
        allowedNFTContract.ownerOf(_tokenId) == msg.sender || 
        allowedNFTContract.getApproved(_tokenId) == msg.sender, 
        "You cant execute this auction just yet"
      );

    // if auction expired/ended
    } else {
      // allow only auction winner or moderators or owner or approved to execute the auction
      require(
        permissionManagement.moderators(msg.sender) == true || 
        allowedNFTContract.ownerOf(_tokenId) == msg.sender || 
        allowedNFTContract.getApproved(_tokenId) == msg.sender ||
        getHighestBidderByTokenID[_tokenId] == msg.sender, 
        "You arent allowed to execute this auction"
      );
    }

    return _executeAuction(_tokenId);
  }

  function _executeAuction(
    uint256 _tokenId
  ) validGasPrice private returns(uint256, uint256) {
    // if there is a valid highest bid
    uint256 _orderId;
    if (getHighestBidByTokenID[_tokenId] != 0) {
      // give the token to the auction winner and carry the transaction
      _orderId = _executeOrder(getHighestBidByTokenID[_tokenId]);
    }

    tokenAutoSellEnabled[_tokenId] = false;
    tokenAuctionEnabled[_tokenId] = false;

    emit EndedAuction(
      _tokenId,
      msg.sender
    );
    
    return (_tokenId, _orderId);
  }

  /// @notice Allows Token Owner to List the Token on the Marketplace with Automated Selling
  /// @param _tokenId ID of the Token to List on the Market with Selling Auto-Enabled
  /// @param _pricePerToken At what Price in Wei, if an Order recevied, should be automatically executed?
  function enableAutoSell(
    uint256 _tokenId,
    uint256 _pricePerToken
  ) external returns(uint256, uint256) {
    permissionManagement.adhereToBanMethod(msg.sender);

    require(allowedNFTContract.ownerOf(_tokenId) == msg.sender || allowedNFTContract.getApproved(_tokenId) == msg.sender || permissionManagement.moderators(msg.sender) == true, "You cant enableAutoSell for this token");

    // if auction is already on, it must be executed first
    require(tokenAuctionEnabled[_tokenId] != true, "Token is in an auction");

    tokenPrice[_tokenId] = _pricePerToken;
    tokenAutoSellEnabled[_tokenId] = true;
    tokenAuctionEnabled[_tokenId] = false;

    emit EnabledAutoSell(
      _tokenId,
      _pricePerToken,
      msg.sender
    );

    return (_tokenId, _pricePerToken);
  }

  /// @notice Allows Token Owner to Disable Auto Selling of their Token
  /// @param _tokenId ID of the Token to List on the Market with Auto-Selling Disabled
  function disableAutoSell(
    uint256 _tokenId
  ) external returns(uint256) {
    permissionManagement.adhereToBanMethod(msg.sender);
    require(allowedNFTContract.ownerOf(_tokenId) == msg.sender || allowedNFTContract.getApproved(_tokenId) == msg.sender || permissionManagement.moderators(msg.sender) == true, "You cant disableAutoSell for this token");

    // if auction is already on, it must be executed first
    require(tokenAuctionEnabled[_tokenId] != true, "Token is in an auction");

    return _disableAutoSell(_tokenId);
  }

  function _disableAutoSell(
    uint256 _tokenId
  ) internal returns(uint256) {
    tokenAutoSellEnabled[_tokenId] = false;
    tokenAuctionEnabled[_tokenId] = false;

    emit DisabledAutoSell(
      _tokenId,
      msg.sender
    );

    return _tokenId;
  }




  // Orders

  struct Order {
    uint256 id;
    address payable buyer;
    uint256 tokenId;
    uint256 price;
    uint256 expiresAt;
    address payable placedBy;
    bool isDuringAuction;
  }

  enum OrderStatus { PLACED, EXECUTED, CANCELLED }

  Order[] public orders;

  // tokenId to orderId[] mapping
  mapping (uint256 => uint256[]) public orderIDsByTokenID;

  // orderId to OrderStatus mapping
  mapping (uint256 => OrderStatus) public orderStatus;

  // tokenId to orderId mapping
  mapping (uint256 => uint256) public getHighestBidByTokenID;

  // tokenId to address mapping
  mapping (uint256 => address) public getHighestBidderByTokenID;



  // Internal Functions relating to Order Management

  function _placeOrder(
    uint256 _tokenId,
    uint256 _expireInSeconds
  ) validGasPrice private returns(uint256) {
    require(allowedNFTContract.ownerOf(_tokenId) != msg.sender, "You cant place an order on your own token");

    uint256 _orderId = orders.length;

    Order memory _order = Order({
      id: _orderId,
      buyer: payable(msg.sender),
      tokenId: _tokenId,
      price: msg.value,
      expiresAt: block.timestamp + _expireInSeconds,
      placedBy: payable(msg.sender),
      isDuringAuction: tokenAuctionEnabled[_tokenId]
    });

    orders.push(_order);
    orderIDsByTokenID[_tokenId].push(_order.id);
    orderStatus[_orderId] = OrderStatus.PLACED;

    if (msg.value > orders[getHighestBidByTokenID[_tokenId]].price) {
      getHighestBidByTokenID[_tokenId] = _orderId;
      getHighestBidderByTokenID[_tokenId] = msg.sender;
    }

    emit OrderPlaced(
      _order.id,
      _order.buyer,
      _order.tokenId,
      _order.price,
      _order.expiresAt,
      _order.placedBy
    );

    return _orderId;
  }

  function _placeOffer(
    uint256 _tokenId,
    uint256 _expireInSeconds,
    address _buyer,
    uint256 _price
  ) validGasPrice private returns(uint256) {
    require(allowedNFTContract.ownerOf(_tokenId) == msg.sender || allowedNFTContract.getApproved(_tokenId) == msg.sender, "You do not have rights to offer this token");
    require(_buyer != msg.sender, "You cant make an offer to yourself");

    uint256 _orderId = orders.length;

    Order memory _order = Order({
      id: _orderId,
      buyer: payable(_buyer),
      tokenId: _tokenId,
      price: _price,
      expiresAt: block.timestamp + _expireInSeconds,
      placedBy: payable(msg.sender),
      isDuringAuction: tokenAuctionEnabled[_tokenId]
    });

    orders.push(_order);
    orderIDsByTokenID[_tokenId].push(_order.id);
    orderStatus[_orderId] = OrderStatus.PLACED;

    emit OrderPlaced(
      _order.id,
      _order.buyer,
      _order.tokenId,
      _order.price,
      _order.expiresAt,
      _order.placedBy
    );

    return _orderId;
  } 

  function _executeOrder(
    uint256 _orderId
  ) validGasPrice private returns(uint256) {
    require(orderStatus[_orderId] != OrderStatus.CANCELLED, "Order already cancelled");
    require(orderStatus[_orderId] != OrderStatus.EXECUTED, "Order already executed");

    // order that is the current highest bid made during an auction cannot expire
    require(
      block.timestamp <= orders[_orderId].expiresAt || 
      (
        orders[_orderId].isDuringAuction == true && 
        getHighestBidByTokenID[orders[_orderId].tokenId] == _orderId
      ), 
      "Order expired"
    );

    require(orders[_orderId].price <= msg.value || orders[_orderId].price <= getBalance(), "Insufficient Contract Balance");

    if (orders[_orderId].price > 0) {
      uint256 beneficiaryPay = SafeMath.div(orders[_orderId].price.mul(taxOnEverySaleInPermyriad), 10000);

      // calculate and split royalty
      (
        address royaltyReceiver, 
        uint256 royaltyAmount
      ) = allowedNFTContract.royaltyInfo(
        allowedNFTContract.getArtifactIDByTokenID(orders[_orderId].tokenId),
        orders[_orderId].price
      );
      Splits(payable(royaltyReceiver)).distributeFunds{value: royaltyAmount}();

      // pay taxes
      (bool success1, ) = permissionManagement.beneficiary().call{value: beneficiaryPay}("");
      require(success1, "Transfer to Beneficiary failed.");

      // pay the owner
      (bool success2, ) = payable(allowedNFTContract.ownerOf(orders[_orderId].tokenId)).call{value: orders[_orderId].price.sub(beneficiaryPay).sub(royaltyAmount)}("");
      require(success2, "Transfer to Token Owner failed.");
    }

    orderStatus[_orderId] = OrderStatus.EXECUTED;

    _disableAutoSell(orders[_orderId].tokenId);

    emit OrderExecuted(_orderId);

    return _orderId;
  }

  function _cancelOrder(
    uint256 _orderId
  ) validGasPrice private returns(uint256) {
    require(orderStatus[_orderId] != OrderStatus.CANCELLED, "Order already cancelled");
    require(orderStatus[_orderId] != OrderStatus.EXECUTED, "Order was already executed, cant be cancelled now");
    require(orderStatus[_orderId] == OrderStatus.PLACED, "Order must be placed to cancel it");

    if (orders[_orderId].price != 0 && orders[_orderId].placedBy == orders[_orderId].buyer) {
      (bool success, ) = orders[_orderId].buyer.call{value: orders[_orderId].price}("");
      require(success, "Transfer to Buyer failed.");
    }

    orderStatus[_orderId] = OrderStatus.CANCELLED;

    emit OrderCancelled(_orderId);

    return _orderId;
  }




  // Public Marketplace Functions

  /// @notice Places Order on a Token
  /// @dev Creates an Order
  /// @param _tokenId Token ID to place an Order On.
  /// @param _expireInSeconds Seconds you want the Order to Expire in.
  function placeOrder(
    uint256 _tokenId,
    uint256 _expireInSeconds
  ) validGasPrice nonReentrant external payable returns(uint256) {
    permissionManagement.adhereToBanMethod(msg.sender);
    require(_expireInSeconds >= 60, "Order must not expire within 60 seconds");
    require(msg.value >= 1, "A non-zero value must be paid");

    uint256 _orderId = _placeOrder(_tokenId, _expireInSeconds);

    // check if token is sellable
    address payable tokenOwner = payable(allowedNFTContract.ownerOf(_tokenId));

    // if sellable, buy
    if (tokenAutoSellEnabled[_tokenId] == true) {
      // if free, complete transaction
      if (tokenPrice[_tokenId] == 0) {
        _executeOrder(_orderId);
        allowedNFTContract.marketTransfer(tokenOwner, msg.sender, _tokenId);
        return _orderId;
      }

      // check if offerPrice matches tokenPrice, if yes, complete transaction.
      if (msg.value >= tokenPrice[_tokenId]) {
        _executeOrder(_orderId);
        allowedNFTContract.marketTransfer(tokenOwner, msg.sender, _tokenId);
        return _orderId;
      }
    }

    return _orderId;
  }

  /// @notice For Token Owner to Offer a Token to someone
  /// @dev Creates an Offer Order
  /// @param _tokenId Token ID to place an Order On.
  /// @param _expireInSeconds Seconds you want the Order to Expire in.
  /// @param _buyer Prospective Buyer Address
  /// @param _price Price at which the Token Owner aims to sell the Token to the Buyer
  function placeOffer(
    uint256 _tokenId,
    uint256 _expireInSeconds,
    address _buyer,
    uint256 _price
  ) validGasPrice external returns(uint256) {
    permissionManagement.adhereToBanMethod(msg.sender);

    require(_expireInSeconds >= 60, "Offer must not expire within 60 seconds");

    uint256 _orderId = _placeOffer(_tokenId, _expireInSeconds, _buyer, _price);

    return _orderId;
  }

  /// @notice For Token Owner to Approve an Order, or for Buyer to Accept an Offer
  /// @dev Executes an Order on Valid Acceptance
  /// @param _orderId ID of the Order to Accept
  function acceptOffer(
    uint256 _orderId
  ) validGasPrice nonReentrant external payable returns(uint256) {
    permissionManagement.adhereToBanMethod(msg.sender);

    Order memory _order = orders[_orderId];
    address tokenOwner = allowedNFTContract.ownerOf(_order.tokenId);
    address tokenApprovedAddress = allowedNFTContract.getApproved(_order.tokenId);

    require(_order.placedBy != msg.sender, "You cant accept your own offer");

    // if auction is on, you cant accept random offers
    require(tokenAuctionEnabled[_order.tokenId] != true, "Cant accept offers on a token during auction");

    // if buyer offered the token owner
    if (_order.placedBy == _order.buyer) {
      require(tokenOwner == msg.sender || tokenApprovedAddress == msg.sender, "Only token owner can accept this offer");

      _executeOrder(_orderId);
      allowedNFTContract.marketTransfer(tokenOwner, _order.buyer, _order.tokenId);
    } else {
      // if token owner/approved address, offered the buyer
      require(_order.buyer == msg.sender, "Only the address that was offered can accept this offer");
      require(_order.placedBy == tokenOwner, "Offer expired as the token is no more owned by the original offerer");

      // require offer price
      require(msg.value >= _order.price, "Insufficient amount sent");

      _executeOrder(_orderId);
      allowedNFTContract.marketTransfer(tokenOwner, _order.buyer, _order.tokenId);

      return _orderId;
    }

    return _orderId;
  }

  /// @notice Allows either party in an Order to cancel the Order
  /// @dev Cancels an Order
  /// @param _orderId ID of the Order to Cancel
  function cancelOffer(
    uint256 _orderId
  ) validGasPrice external returns(uint256) {
    permissionManagement.adhereToBanMethod(msg.sender);

    Order memory _order = orders[_orderId];
    address tokenOwner = allowedNFTContract.ownerOf(_order.tokenId);
    address tokenApprovedAddress = allowedNFTContract.getApproved(_order.tokenId);

    require(_order.placedBy == msg.sender || tokenOwner == msg.sender || tokenApprovedAddress == msg.sender, "You do not have the right to cancel this offer");

    // if your bid was the highest on an auctioned token, then you cannot cancel
    if (getHighestBidByTokenID[_order.tokenId] == _orderId && _order.isDuringAuction == true) {
      revert("Highest Bid cant be cancelled during an Auction");
    }

    _cancelOrder(_orderId);

    return _orderId;
  }
}