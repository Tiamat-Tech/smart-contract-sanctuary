//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.3;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract RankingNFT is ERC721, Ownable,  Pausable{

    event OnMintNFT(address indexed _actualMinter, string indexed _tokenURI, uint256 _newItemId, uint256 _initERC20Price);
    event OnSetForSaleWithGoalPrice(address indexed _sender, uint256 indexed _tokenId, bool indexed _isForSale, uint256 _goalPrice, uint256 _numberOfTransfers);
    event OnBuyToken(uint256 indexed _tokenId, address indexed _buyer, uint256 indexed _price, uint256 _numberOfTransfers);

    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    uint256 MAX_PRICE = type(uint256).max;
    uint256 MIN_PRICE = 0;

    uint256 public FEE_MINT_FOR_COMPANY = 1000; //100% will divide into 40%(winner creating this survey), 30%(company) and 30%(random attenders(10% X 3 attenders))
    uint256 public GENERAL_FEE_FOR_COMPANY = 25; //2.5% for general buying transaction

    address constant CURRENCY_RANKING_ERC20_TOKEN_ADDRESS = address(0x1090f7eF7Af960ad6167bFc5E842563B45d64C21);

    struct PurchaseInfo {
        address seller;
        address buyer; 
        uint256 goalPrice; //Owner wants to sell with at least this price
        uint256 finalPrice; //the final price sold
        uint startDate;
        uint endDate;
    }

    struct TransactionHistory {
        uint256 tokenId;
        string tokenURI;
        address mintedBy;
        address payable currentOwner; //mint person or last buyer 
        uint256 currentPrice; //0 or last buyer's price
        mapping(uint256 => PurchaseInfo) purchaseInfoList; //Whenever buying process completed
        uint256 numberOfTransfers; //buying process count
        bool forSale;
    }

    // check if token URI exists
    mapping(string => bool) public tokenURIExists; 

    mapping(uint256 => TransactionHistory) public allTransactionHistory;

    // the name and symbol for the NFT
    constructor() ERC721("RankingNFT", "RANKNFT") {
    }

    // Create a function to mint/create the NFT
    // recipient takes a type of address. This is the wallet address of the user that should receive the NFT minted using the smart contract
    // tokenURI takes a string that contains metadata about the NFT
    function mintNFT(string memory _tokenURI, uint256 _initERC20Price) public payable whenNotPaused returns (uint256) {
        // check if thic fucntion caller is not an zero address account
        require(msg.sender != address(0));

        // check if the token URI already exists or not
        require(!tokenURIExists[_tokenURI]);        

        // check if the token URI already exists or not
        require(bytes(_tokenURI).length > 10 && bytes(_tokenURI).length < 1024 * 8);        

        require(_initERC20Price > MIN_PRICE && _initERC20Price <= MAX_PRICE);        


        //pay from buyer to owner(company) as initial step
        IERC20 token = IERC20(CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);
        uint256 beforeBalanceForCompany = token.balanceOf(owner());
        uint256 beforeBalanceForOwner = token.balanceOf(msg.sender);

        require(beforeBalanceForOwner >= _initERC20Price);

        bool isApproved = token.approve(msg.sender, _initERC20Price);
        require(isApproved);

        bool isSuccess = token.transferFrom(msg.sender, owner(), _initERC20Price);
        require(isSuccess);

        uint256 afterBalanceForCompany = token.balanceOf(owner());    
        uint256 afterBalanceForOwner = token.balanceOf(msg.sender);
        //pay from buyer to owner(company) as initial step


        tokenIds.increment();

        uint256 newItemId = tokenIds.current();

        _mint(msg.sender, newItemId); //Mint sents token to company at first time
        _setTokenURI(newItemId, _tokenURI);

        PurchaseInfo memory initPurchase = PurchaseInfo(owner(), msg.sender, _initERC20Price, _initERC20Price, block.timestamp, block.timestamp);
        TransactionHistory storage newHistory = allTransactionHistory[newItemId];
        newHistory.tokenId = newItemId;
        newHistory.tokenURI = _tokenURI;
        newHistory.mintedBy = owner();
        newHistory.currentOwner = msg.sender; //mint person or last buyer 
        newHistory.currentPrice = _initERC20Price; //0 or last buyer's price
        newHistory.purchaseInfoList[0] = initPurchase; //Whenever buying process completed
        newHistory.numberOfTransfers = 0; //buying process count
        newHistory.forSale = false;        

        // make passed token URI as exists
        tokenURIExists[_tokenURI] = true;

        emit OnMintNFT(msg.sender, _tokenURI, newItemId, _initERC20Price);

        // returns the id for the newly created token
        return newItemId;
  }

  // get balance of ERC20
  function getBalanceOfERC20(address _userAddress) public view returns(uint256) {
    IERC20 token = IERC20(CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);
    uint256 balance = token.balanceOf(_userAddress);
    return balance;
  }    

  // get owner of the token
  function getTokenOwner(uint256 _tokenId) public view returns(address) {
    address _tokenOwner = ownerOf(_tokenId);
    return _tokenOwner;
  }    

  // get metadata of the token
  function getTokenMetaData(uint _tokenId) public view returns(string memory) {
    string memory tokenMetaData = tokenURI(_tokenId);
    return tokenMetaData;
  }  

  // get total number of tokens minted so far
  function getNumberOfTokensMinted() public view returns(uint256) {
    uint256 totalNumberOfTokensMinted = totalSupply();
    return totalNumberOfTokensMinted;
  }

  // get total number of tokens owned by an address
  function getTotalNumberOfTokensOwnedByAddress(address _owner) public view returns(uint256) {
    uint256 totalNumberOfTokensOwned = balanceOf(_owner);
    return totalNumberOfTokensOwned;
  }    

  // check if the token already exists
  function getTokenExists(uint256 _tokenId) public view returns(bool) {
    bool tokenExists = _exists(_tokenId);
    return tokenExists;
  }  

  function getNFTContractAddress() public view returns(address) {
    return address(this);
  }    

  function getOwnerOfContract() public view returns(address) {
    return owner();
  }    


  function getTransHistoryByTokenId(uint256 _tokenId) public view returns(uint256, string memory, address, address payable, uint256, uint256, bool) {
    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
    return (transHistory.tokenId, transHistory.tokenURI, transHistory.mintedBy, transHistory.currentOwner, transHistory.currentPrice, transHistory.numberOfTransfers, transHistory.forSale);
  }    

  function getNumberOfTransferByTokenId(uint256 _tokenId) public view returns(uint256) {
    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
    return transHistory.numberOfTransfers;
  }    

  function getPurchaseInfoByTokenId(uint256 _tokenId, uint256 _numberOfTransfers) public view returns(address, address, uint256, uint256, uint, uint) {
    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
    PurchaseInfo memory info = transHistory.purchaseInfoList[_numberOfTransfers];
    return (info.seller, info.buyer, info.goalPrice, info.finalPrice, info.startDate, info.endDate);
  }   

  // switch between set for sale and set not for sale
  function setForSaleWithGoalPrice(uint256 _tokenId, bool _isForSale, uint256 _goalPrice) public onlyOwner whenNotPaused returns(bool) {
    // require caller of the function is not an empty address
    require(msg.sender != address(0));
    // require that token should exist
    require(_exists(_tokenId));
    // get the token's owner
    address tokenOwner = ownerOf(_tokenId);
    // check that token's owner should be equal to the caller of the function
    require(tokenOwner == msg.sender);

    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
    if(_isForSale) //For Sale
    {
        require(_goalPrice > MIN_PRICE && _goalPrice <= MAX_PRICE);

        transHistory.forSale = true;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller = tokenOwner;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = address(0);
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice = _goalPrice;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate = block.timestamp;        
    }
    else //To stop sale
    {
        require(_goalPrice <= MIN_PRICE );

        transHistory.forSale = false;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller = tokenOwner;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = address(0);
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate = 0;           
    }

    emit OnSetForSaleWithGoalPrice(msg.sender, _tokenId, _isForSale, _goalPrice, transHistory.numberOfTransfers);    

    return _isForSale;
  }  

  function buyToken(uint256 _tokenId) public payable whenNotPaused returns(bool) {
    // check if the function caller is not an zero account address
    require(msg.sender != address(0));
    // check if the token id of the token being bought exists or not
    require(_exists(_tokenId));
    // get the token's owner
    address tokenOwner = ownerOf(_tokenId);
    // token's owner should not be an zero address account
    require(tokenOwner != address(0));
    // the one who wants to buy the token should not be the token's owner
    require(tokenOwner != msg.sender);
    
    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];

    // token should be for sale
    require(transHistory.forSale);

    uint256 companyPortion = (transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice / 1000) * GENERAL_FEE_FOR_COMPANY;
    uint256 currentOwnerPortion = transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice - companyPortion;
    
    //company's balance
    IERC20 token = IERC20(CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);
    uint256 beforeBalanceForBuyer = token.balanceOf(msg.sender); //buyer's balance
    require(beforeBalanceForBuyer >= companyPortion);
    bool isApproved = token.approve(msg.sender, companyPortion);
    require(isApproved);    
    bool isSuccess = token.transferFrom(msg.sender, owner(), companyPortion);
    require(isSuccess);    

    //owner's balance
    uint256 beforeBalanceForBuyer1 = token.balanceOf(msg.sender); //buyer's balance
    require(beforeBalanceForBuyer1 >= currentOwnerPortion);
    bool isApproved1 = token.approve(msg.sender, currentOwnerPortion);    
    require(isApproved1);    
    bool isSuccess1 = token.transferFrom(msg.sender, transHistory.currentOwner, currentOwnerPortion);
    require(isSuccess1);        

    // transfer the token from owner to the caller of the function (buyer)
    _transfer(tokenOwner, msg.sender, _tokenId);

    transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = msg.sender;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].endDate = block.timestamp; 

    emit OnBuyToken(_tokenId, msg.sender, transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice, transHistory.numberOfTransfers);    

    transHistory.currentOwner = msg.sender;
    transHistory.currentPrice = transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice;
    transHistory.numberOfTransfers += 1;
    transHistory.forSale = false;

    return true;
  }
}