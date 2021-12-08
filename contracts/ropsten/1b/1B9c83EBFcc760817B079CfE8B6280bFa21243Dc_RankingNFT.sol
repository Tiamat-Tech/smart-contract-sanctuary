//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.3;

//import "hardhat/console.sol";

// implements the ERC721 standard
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// keeps track of the number of tokens issued
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RankingNFT is ERC721, Ownable {
    event OnMintNFT(address indexed _recipient, string indexed _tokenURI, uint256 _newItemId);
    event OnSetForSaleWithGoalPrice(address indexed _sender, uint256 indexed _tokenId, bool indexed _isForSale, uint256 _goalPrice);
    event OnBuyToken(uint256 indexed _tokenId, address indexed _buyer, uint256 indexed _price, uint256 _numberOfTransfers);

    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    uint256 MAX_PRICE = type(uint256).max;
    uint256 MIN_PRICE = 0;

    uint256 public FEE_MINT_FOR_COMPANY = 1000; //100% will divide into 40%(winner creating this survey), 30%(company) and 30%(random attenders(10% X 3 attenders))
    uint256 public GENERAL_FEE_FOR_COMPANY = 25; //2.5% for general buying transaction

    address public constant CURRENCY_RANKING_ERC20_TOKEN_ADDRESS = 0x234Dd3FE2fE48fF08f377c7cf999EE63c4C92879;

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
    function mintNFT(address _recipient, string memory _tokenURI) public onlyOwner payable returns (uint256) {

        //console.log("mintNFT, Sender=%s, _recipient=%s, _tokenURI=%s", msg.sender, _recipient, _tokenURI);

        // check if thic fucntion caller is not an zero address account
        require(msg.sender != address(0));

        // check if the token URI already exists or not
        require(!tokenURIExists[_tokenURI]);        

        // check if the token URI already exists or not
        require(bytes(_tokenURI).length > 10 && bytes(_tokenURI).length < 1024 * 8);        
        require(msg.value > MIN_PRICE && msg.value <= MAX_PRICE);

        //console.log("mintNFT, msg.sender=%s, address(this)=%s", msg.sender, address(this)); 

        IERC20 token = IERC20(CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);
        uint256 buyerBalance = token.balanceOf(msg.sender);
        //console.log("mintNFT, buyerBalance=%s", buyerBalance);        
        require(buyerBalance > MIN_PRICE && buyerBalance <= MAX_PRICE);

        uint256 companyPortion = msg.value;

        uint256 beforeBalanceForCompany = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), companyPortion);
        uint256 afterBalanceForCompany = token.balanceOf(address(this));    
        //console.log("mintNFT, beforeBalanceForCompany=%s, afterBalanceForCompany=%s", beforeBalanceForCompany, afterBalanceForCompany);

        tokenIds.increment();

        uint256 newItemId = tokenIds.current();
        //console.log("mintNFT, newItemId=%s, _tokenURI=%s", newItemId, _tokenURI);

        _mint(_recipient, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        PurchaseInfo memory initPurchase = PurchaseInfo(msg.sender, msg.sender, 0, msg.value, block.timestamp, block.timestamp);

        TransactionHistory storage newHistory = allTransactionHistory[newItemId];
        newHistory.tokenId = newItemId;
        newHistory.tokenURI = _tokenURI;
        newHistory.mintedBy = address(this);
        newHistory.currentOwner = msg.sender; //mint person or last buyer 
        newHistory.currentPrice = msg.value; //0 or last buyer's price
        newHistory.purchaseInfoList[0] = initPurchase; //Whenever buying process completed
        newHistory.numberOfTransfers = 1; //buying process count
        newHistory.forSale = false;        

        // make passed token URI as exists
        tokenURIExists[_tokenURI] = true;

        //console.log("mintNFT, newItemId=%s, _tokenURI=%s, tokenURIExists[_tokenURI]=%s", newItemId, _tokenURI, tokenURIExists[_tokenURI]);

        emit OnMintNFT(_recipient, _tokenURI, newItemId);

        // returns the id for the newly created token
        return newItemId;
    }

  // get owner of the token
  function getTokenOwner(uint256 _tokenId) public view returns(address) {
    address _tokenOwner = ownerOf(_tokenId);
    //console.log("getTokenOwner, _tokenOwner=%s", _tokenOwner);
    return _tokenOwner;
  }    

  // get metadata of the token
  function getTokenMetaData(uint _tokenId) public view returns(string memory) {
    string memory tokenMetaData = tokenURI(_tokenId);
    //console.log("getTokenMetaData, tokenMetaData=%s", tokenMetaData);    
    return tokenMetaData;
  }  

  // get total number of tokens minted so far
  function getNumberOfTokensMinted() public view returns(uint256) {
    uint256 totalNumberOfTokensMinted = totalSupply();
    //console.log("getNumberOfTokensMinted, totalNumberOfTokensMinted=%s", totalNumberOfTokensMinted);        
    return totalNumberOfTokensMinted;
  }

  // get total number of tokens owned by an address
  function getTotalNumberOfTokensOwnedByAddress(address _owner) public view returns(uint256) {
    uint256 totalNumberOfTokensOwned = balanceOf(_owner);
    //console.log("getTotalNumberOfTokensOwnedByAddress, totalNumberOfTokensOwned=%s", totalNumberOfTokensOwned);     
    return totalNumberOfTokensOwned;
  }    

  // check if the token already exists
  function getTokenExists(uint256 _tokenId) public view returns(bool) {
    bool tokenExists = _exists(_tokenId);
    //console.log("getTokenExists, _tokenId=%s, tokenExists=%s", _tokenId, tokenExists);     
    return tokenExists;
  }  

  // switch between set for sale and set not for sale
  function setForSaleWithGoalPrice(uint256 _tokenId, bool _isForSale, uint256 _goalPrice) public onlyOwner returns(bool) {
    // require caller of the function is not an empty address
    require(msg.sender != address(0));
    // require that token should exist
    require(_exists(_tokenId));
    // get the token's owner
    address tokenOwner = ownerOf(_tokenId);
    // check that token's owner should be equal to the caller of the function
    require(tokenOwner == msg.sender);

    //console.log("setForSaleWithGoalPrice, _tokenId=%s, msg.sender=%s, _goalPrice=%s", _tokenId, msg.sender, _goalPrice);         

    if(_isForSale) //For Sale
    {
        require(_goalPrice > MIN_PRICE && _goalPrice <= MAX_PRICE);

        //console.log("setForSaleWithGoalPrice FOR SALE, _tokenId=%s, msg.sender=%s, _goalPrice=%s", _tokenId, msg.sender, _goalPrice);         

        TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
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

        //console.log("setForSaleWithGoalPrice STOP SALE, _tokenId=%s, msg.sender=%s, _goalPrice=%s", _tokenId, msg.sender, _goalPrice);         

        TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
        transHistory.forSale = false;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller = tokenOwner;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = address(0);
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate = 0;           
    }

    emit OnSetForSaleWithGoalPrice(msg.sender, _tokenId, _isForSale, _goalPrice);    

    return _isForSale;
  }  

  function buyToken(uint256 _tokenId) public payable returns(bool){
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
    
    require(msg.value > MIN_PRICE && msg.value <= MAX_PRICE);

    //console.log("buyToken, _tokenId=%s, buyer=%s, price=%s", _tokenId, msg.sender, msg.value);
    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];

    // price sent in to buy should be equal to or more than the token's price
    require(msg.value >= transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice);
    // token should be for sale
    require(transHistory.forSale);


    uint256 companyPortion = (msg.value / 1000) * GENERAL_FEE_FOR_COMPANY;
    uint256 currentOwnerPortion = msg.value - companyPortion;

    IERC20 token = IERC20(CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);
    uint256 beforeBalanceForCompany = token.balanceOf(address(this));
    token.transferFrom(msg.sender, address(this), companyPortion);
    uint256 afterBalanceForCompany = token.balanceOf(address(this));    

    //console.log("buyToken, _tokenId=%s, beforeBalanceForCompany=%s, afterBalanceForCompany=%s", _tokenId, beforeBalanceForCompany, afterBalanceForCompany);


    uint256 beforeBalanceForOwner = token.balanceOf(transHistory.currentOwner);
    token.transferFrom(msg.sender, transHistory.currentOwner, currentOwnerPortion);
    uint256 afterBalanceForOwner = token.balanceOf(transHistory.currentOwner);

    //console.log("buyToken, _tokenId=%s, beforeBalanceForOwner=%s, afterBalanceForOwner=%s", _tokenId, beforeBalanceForOwner, afterBalanceForOwner);


    // transfer the token from owner to the caller of the function (buyer)
    _transfer(tokenOwner, msg.sender, _tokenId);

    transHistory.forSale = false;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = msg.sender;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = msg.value;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].endDate = block.timestamp; 

    // update the token's current owner
    transHistory.currentOwner = msg.sender;
    // update the how many times this token was transfered
    transHistory.numberOfTransfers += 1;
    transHistory.currentPrice = msg.value;

    //console.log("buyToken, _tokenId=%s, transHistory.currentOwner=%s, transHistory.numberOfTransfers=%s", _tokenId, transHistory.currentOwner, transHistory.numberOfTransfers);

    emit OnBuyToken(_tokenId, msg.sender, msg.value, transHistory.numberOfTransfers);


    return true;
  }

}