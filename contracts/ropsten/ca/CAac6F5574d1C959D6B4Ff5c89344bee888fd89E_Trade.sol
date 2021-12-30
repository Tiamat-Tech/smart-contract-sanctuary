//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.3;


//import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./RankingERC20Token.sol";
import "./RankingNFT.sol";


/*
import "hardhat/console.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/GSN/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SignedSafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SafeMath.sol";
import "./RankingERC20Token.sol";
import "./RankingNFT.sol";
*/

contract Trade is Ownable, Pausable {
    using SignedSafeMath for int256;
    using SafeMath for uint256;

    address public creatorAddress;
    RankingERC20Token public erc20Token;
    RankingNFT public nftToken;

    event OnMintNFT(address indexed _actualMinter, string indexed _tokenURI, uint256 _newItemId, uint256 _initERC20Price);
    event OnSetForSaleWithGoalPrice(address indexed _sender, uint256 indexed _tokenId, bool indexed _isForSale, uint256 _goalPrice, uint256 _numberOfTransfers);
    event OnBuyToken(uint256 indexed _tokenId, address indexed _buyer, uint256 indexed _price, uint256 _numberOfTransfers);

    uint256 MAX_PRICE = type(uint256).max;
    uint256 MIN_PRICE = 0;

    uint MIN_INPUT_TOKEN_URL_SIZE = 10;
    uint MAX_INPUT_TOKEN_URL_SIZE = 1024 * 8;

    uint256 public FEE_MINT_FOR_COMPANY = 1000; //100% will divide into 40%(winner creating this survey), 30%(company) and 30%(random attenders(10% X 3 attenders))
    uint256 public GENERAL_FEE_FOR_COMPANY = 25; //2.5% for general buying transaction

    //address constant CURRENCY_RANKING_ERC20_TOKEN_ADDRESS = address(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8);

    struct PurchaseInfo {
        address seller;
        address payable buyer; 
        uint256 goalPrice; //Owner wants to sell with at least this price
        uint256 finalPrice; //the final price sold
        uint256 companyFee;
        uint256 ownerFee;
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

    //all users' token id list
    mapping(address => uint256[]) public allUsersTokenIds;
    
    constructor(RankingERC20Token _erc20Token, RankingNFT _nftToken) {
        creatorAddress = msg.sender;
        erc20Token = _erc20Token;
        nftToken = _nftToken;
    }

    function mintNFT(string memory _tokenURI, uint256 _initERC20Price) public returns (uint256) {
        //console.log("mintNFT, Let's start to mint, _tokenURI=%s, _initERC20Price=%s", _tokenURI, _initERC20Price);
        //console.log("mintNFT, msg.sender=%s, address(0)=%s, address(this)=%s", msg.sender, address(0), address(this));
        //console.log("mintNFT, msg.sender=%s, msg.value=%s", msg.sender, msg.value);

        // check if thic fucntion caller is not an zero address account
        require(msg.sender != address(0));

        //console.log("mintNFT, tokenURIExists[_tokenURI]=%s", tokenURIExists[_tokenURI]);
        // check if the token URI already exists or not
        require(!tokenURIExists[_tokenURI]);        

        require(_initERC20Price >= FEE_MINT_FOR_COMPANY && _initERC20Price <= MAX_PRICE, "goalPrice must be bigger than 1000 token");
    
        //console.log("mintNFT, bytes(_tokenURI).length=", bytes(_tokenURI).length);

        // check if the token URI already exists or not
        require(bytes(_tokenURI).length >= MIN_INPUT_TOKEN_URL_SIZE && bytes(_tokenURI).length < MAX_INPUT_TOKEN_URL_SIZE);        

        //console.log("mintNFT, _initERC20Price2=%s, MIN_PRICE=%s, MAX_PRICE=%s", _initERC20Price, MIN_PRICE, MAX_PRICE);

        require(_initERC20Price > MIN_PRICE && _initERC20Price <= MAX_PRICE);        

        //console.log("mintNFT, _initERC20Price3=%s", _initERC20Price);

        //pay from buyer to owner(company) as initial step
        //IERC20 token = IERC20(CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);
        //console.log("mintNFT, msg.sender=%s, CURRENCY_RANKING_ERC20_TOKEN_ADDRESS=%s", msg.sender, CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);

        //uint256 beforeBalanceForOwner = erc20Token.balanceOf(owner());
        //console.log("mintNFT, owner()=%s, beforeBalanceForOwner=%s, address(this)=%s", owner(), beforeBalanceForOwner, address(this));

        uint256 beforeBalanceForSender = erc20Token.balanceOf(msg.sender);
        //console.log("mintNFT, msg.sender=%s, beforeBalanceForSender=%s", msg.sender, beforeBalanceForSender);

        require(beforeBalanceForSender >= _initERC20Price);

        //console.log("mintNFT, before token.approve, msg.sender=%s, owner()=%s", msg.sender, owner());
        bool isApproved = erc20Token.myApprove(msg.sender, owner(), _initERC20Price);
        require(isApproved);
        //console.log("mintNFT, isApproved=%s", isApproved);

        uint256 allowance = erc20Token.myAllowance(msg.sender, owner());
        //console.log("mintNFT, allowance=%s, _initERC20Price=%s", allowance, _initERC20Price);

        require(allowance>=_initERC20Price);

        //console.log("mintNFT, before transfer, msg.sender=%s, owner()=%s, _initERC20Price=%s", msg.sender, owner(), _initERC20Price);  
        bool isSuccess = erc20Token.myTransfer(msg.sender, owner(), _initERC20Price);
        require(isSuccess);
        //console.log("mintNFT, transfer, isSuccess=%s", isSuccess);        

        isSuccess = erc20Token.myDecreaseAllowance(msg.sender, owner(), _initERC20Price);
        require(isSuccess);
        //console.log("mintNFT, decreaseAllowance, isSuccess=%s", isSuccess);        
        //pay from buyer to owner(company) as initial step


        uint256 newItemId = nftToken.mintNFT(msg.sender, _tokenURI);
        //console.log("mintNFT, newItemId=%s", newItemId);           

        PurchaseInfo memory initPurchase = PurchaseInfo(owner(), msg.sender, _initERC20Price, _initERC20Price, _initERC20Price, 0, block.timestamp, block.timestamp);
        TransactionHistory storage newHistory = allTransactionHistory[newItemId];
        newHistory.tokenId = newItemId;
        newHistory.tokenURI = _tokenURI;
        newHistory.mintedBy = owner();
        newHistory.currentOwner = msg.sender; //mint person or last buyer 
        newHistory.currentPrice = _initERC20Price; //0 or last buyer's price
        newHistory.purchaseInfoList[0] = initPurchase; //Whenever buying process completed
        newHistory.numberOfTransfers = 1; //buying process count
        newHistory.forSale = false;        

        // make passed token URI as exists
        tokenURIExists[_tokenURI] = true;

        //console.log("mintNFT, complete MINT, msg.sender=%s, newItemId=%s, newHistory.numberOfTransfers=%s", msg.sender, newItemId, newHistory.numberOfTransfers);           


        //Saving to show user's token ids
        allUsersTokenIds[msg.sender].push(newItemId);

        //console.log("mintNFT, allUsersTokenIds[%s]=%s", msg.sender, allUsersTokenIds[msg.sender].length);  

        emit OnMintNFT(msg.sender, _tokenURI, newItemId, _initERC20Price);

        // returns the id for the newly created token
        return newItemId;
  }

  // get balance of ERC20
  function getBalanceOfERC20(address _userAddress) public view returns(uint256) {
    //IERC20 token = IERC20(CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);
    return erc20Token.balanceOf(_userAddress);
  }    

  // get all user's token ids
  function getAllUserTokenIds(address _userAddress) public view returns(uint256[] memory) {
    uint256[] memory list = allUsersTokenIds[_userAddress];
    return list;
  }   

  // get owner of the token
  function getNFTOwner(uint256 _tokenId) public view returns(address) {
    address _tokenOwner = nftToken.ownerOf(_tokenId);
    return _tokenOwner;
  }    

  // get metadata of the token
  function getNFTMetaData(uint _tokenId) public view returns(string memory) {
    string memory tokenMetaData = nftToken.tokenURI(_tokenId);
    return tokenMetaData;
  }  

  // get total number of tokens minted so far
  function getNumberOfNFTMinted() public view returns(uint256) {
    uint256 totalNumberOfTokensMinted = nftToken.totalSupply();
    return totalNumberOfTokensMinted;
  }

  // get total number of tokens owned by an address
  function getTotalNumberOfNFTOwnedByAddress(address _owner) public view returns(uint256) {
    uint256 totalNumberOfTokensOwned = nftToken.balanceOf(_owner);
    return totalNumberOfTokensOwned;
  }    

  // check if the token already exists
  function getNFTExists(uint256 _tokenId) public view returns(bool) {

    string memory tokenMetaData = nftToken.tokenURI(_tokenId);
    bool tokenExists = (bytes(tokenMetaData).length >= MIN_INPUT_TOKEN_URL_SIZE) ? true : false;
    //console.log("getNFTExists, _tokenId=%s, bytes(tokenMetaData).length=%s, tokenExists=%s",  _tokenId, bytes(tokenMetaData).length, tokenExists);
    return tokenExists;
  }  

  function getCurrentContractAddress() public view returns(address) {
    return address(this);
  }    

  function getCreatorOfNFTContract() public view returns(address) {
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

  function getPurchaseInfoByTokenId(uint256 _tokenId, uint256 _numberOfTransfers) public view returns(address seller, address buyer, uint256 goalPrice, uint256 finalPrice, uint256 companyFee, uint256 ownerFee, uint startDate, uint endDate) {
    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
    PurchaseInfo memory info = transHistory.purchaseInfoList[_numberOfTransfers];
    return (info.seller, info.buyer, info.goalPrice, info.finalPrice, info.companyFee, info.ownerFee, info.startDate, info.endDate);
  }   

  // switch between set for sale and set not for sale
  function setForSaleWithGoalPrice(uint256 _tokenId, bool _isForSale, uint256 _goalPrice) public whenNotPaused returns(bool) {
    //console.log("setForSaleWithGoalPrice, _tokenId=%s, _isForSale=%s, _goalPrice=%s",  _tokenId, _isForSale, _goalPrice);
    // require caller of the function is not an empty address
    require(msg.sender != address(0));

    //console.log("setForSaleWithGoalPrice, _tokenId=%s, getNFTExists(_tokenId)=%s",  _tokenId, getNFTExists(_tokenId));

    // require that token should exist
    require(getNFTExists(_tokenId));

    // get the token's owner
    address tokenOwner = nftToken.ownerOf(_tokenId);

    //console.log("setForSaleWithGoalPrice, _tokenId=%s, tokenOwner=%s, msg.sender=%s",  _tokenId, tokenOwner, msg.sender);

    // check that token's owner should be equal to the caller of the function
    require(tokenOwner == msg.sender);

    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];

    //console.log("setForSaleWithGoalPrice, _tokenId=%s, transHistory.numberOfTransfers=%s, _isForSale=%s",  _tokenId, transHistory.numberOfTransfers, _isForSale);
    if(_isForSale) //For Sale
    {
        require(_goalPrice >= FEE_MINT_FOR_COMPANY && _goalPrice <= MAX_PRICE, "goalPrice must be bigger than 1000 token");

        //console.log("setForSaleWithGoalPrice, true, _tokenId=%s, nftToken.owner()=%s",  _tokenId, nftToken.owner());
        transHistory.forSale = true;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller = tokenOwner;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = address(0);
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice = _goalPrice;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].companyFee = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].ownerFee = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate = block.timestamp;     
        nftToken.mySetApprovalForAll(msg.sender, nftToken.owner(), true);

        bool isApproved1 = nftToken.isApprovedForAll(msg.sender, nftToken.owner());
        //console.log("setForSaleWithGoalPrice, true, _tokenId=%s, isApproved1=%s, nftToken.owner()=%s",  _tokenId, isApproved1, nftToken.owner());
        require(isApproved1, "not allowed to transfer");
        nftToken.transferFrom(msg.sender, nftToken.owner(), _tokenId);

    }
    else //To stop sale
    {
        require(_goalPrice <= MIN_PRICE, "goalPrice must be 0" );

        console.log("setForSaleWithGoalPrice, false, _tokenId=%s, nftToken.owner()=%s",  _tokenId, nftToken.owner());
        transHistory.forSale = false;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller = tokenOwner;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = address(0);
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].companyFee = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].ownerFee = 0;        
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate = 0;

        nftToken.transferFrom(nftToken.owner(), msg.sender, _tokenId);       
        nftToken.mySetApprovalForAll(msg.sender, nftToken.owner(), false);   

    }

    //console.log("setForSaleWithGoalPrice, transHistory.numberOfTransfers=%s, transHistory.forSale=%s", transHistory.numberOfTransfers, transHistory.forSale);
    //console.log("setForSaleWithGoalPrice, transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller);
    //console.log("setForSaleWithGoalPrice, transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer);
    //console.log("setForSaleWithGoalPrice, transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice);
    //console.log("setForSaleWithGoalPrice, transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice);
    //console.log("setForSaleWithGoalPrice, transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate);

    emit OnSetForSaleWithGoalPrice(msg.sender, _tokenId, _isForSale, _goalPrice, transHistory.numberOfTransfers);    

    return _isForSale;
  }  

  function buyToken(uint256 _tokenId) public whenNotPaused returns(bool) {
    //console.log("buyToken, msg.sender=%s, _tokenId=%s", msg.sender, _tokenId);      
    // check if the function caller is not an zero account address
    require(msg.sender != address(0));
    // check if the token id of the token being bought exists or not
    require(getNFTExists(_tokenId));
    // get the token's owner
    address tokenOwner = nftToken.ownerOf(_tokenId);
    //console.log("buyToken, msg.sender=%s, tokenOwner=%s", msg.sender, tokenOwner);      

    // token's owner should not be an zero address account
    require(tokenOwner != address(0));
    // the one who wants to buy the token should not be the token's owner
    require(tokenOwner != msg.sender);
    
    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
    //console.log("buyToken, transHistory.numberOfTransfers=%s, transHistory.forSale=%s", transHistory.numberOfTransfers, transHistory.forSale);  

    // token should be for sale
    require(transHistory.forSale);

    int256 tempFullPrice = int256(transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice);
    uint256 companyPortion = uint256(tempFullPrice.mul(int256(GENERAL_FEE_FOR_COMPANY)).div(1000));
    uint256 currentOwnerPortion = uint256(tempFullPrice.sub(int256(companyPortion)));
    //console.log("buyToken, tempGoalPrice=%s, companyPortion=%s, currentOwnerPortion=%s", uint256(tempFullPrice), uint256(companyPortion), uint256(currentOwnerPortion));

    //company's balance
    //IERC20 token = IERC20(CURRENCY_RANKING_ERC20_TOKEN_ADDRESS);
    uint256 balanceForBuyer = erc20Token.balanceOf(msg.sender); //buyer's balance
    //uint256 balanceForCompany = erc20Token.balanceOf(owner()); //company's balance    
    //console.log("buyToken, beforeBalanceForBuyer=%s, beforeBalanceForCompany=%s", balanceForBuyer, balanceForCompany);  
    require(balanceForBuyer >= companyPortion);

    bool isApproved = erc20Token.myApprove(msg.sender, owner(), companyPortion);
    require(isApproved);    
    //console.log("buyToken, owner(), isApproved=%s", isApproved); 

    uint256 allowance = erc20Token.myAllowance(msg.sender, owner());
    //console.log("buyToken, allowance=%s, companyPortion=%s", allowance, companyPortion);    
    require(allowance >= companyPortion);     

    bool isSuccess = erc20Token.myTransfer(msg.sender, owner(), companyPortion);
    require(isSuccess);    
    //console.log("buyToken, transfer owner(), isSuccess=%s", isSuccess);  
    balanceForBuyer = erc20Token.balanceOf(msg.sender); //buyer's balance
    //balanceForCompany = erc20Token.balanceOf(owner()); //buyer's balance
    //console.log("buyToken, myTransfer msg.sender=%s, balanceForBuyer=%s", msg.sender, balanceForBuyer);  
    //console.log("buyToken, myTransfer owner()=%s, afterBalanceForCompany=%s", owner(), balanceForCompany);      

    isSuccess = erc20Token.myDecreaseAllowance(msg.sender, owner(), companyPortion);
    require(isSuccess);
    //console.log("buyToken, decreaseAllowance owner(), isSuccess=%s", isSuccess);            

    //owner's balance
    balanceForBuyer = erc20Token.balanceOf(msg.sender); //buyer's balance
    uint256 balanceForTokenOwner = erc20Token.balanceOf(transHistory.currentOwner); //company's balance    
    //console.log("buyToken, beforeBalanceForBuyer2=%s, beforeBalanceForTokenOwner=%s", balanceForBuyer, balanceForTokenOwner);  

    require(balanceForBuyer >= currentOwnerPortion);
    isApproved = erc20Token.myApprove(msg.sender, transHistory.currentOwner, currentOwnerPortion);    
    require(isApproved);    
    //console.log("buyToken, tokenOwner isApproved=%s", isApproved);  

    allowance = erc20Token.myAllowance(msg.sender, transHistory.currentOwner);
    //console.log("buyToken, myAllowance, allowance=%s, currentOwnerPortion=%s", allowance, currentOwnerPortion);    
    require(allowance >= currentOwnerPortion);         

    //console.log("buyToken, transferFrom, msg.sender=%s, transHistory.currentOwner=%s, currentOwnerPortion=%s", msg.sender, transHistory.currentOwner, currentOwnerPortion);  
    isSuccess = erc20Token.myTransfer(msg.sender, transHistory.currentOwner, currentOwnerPortion);
    require(isSuccess);        
    //console.log("buyToken, transfer tokenOwner, isSuccess=%s", isSuccess);  

    isSuccess = erc20Token.myDecreaseAllowance(msg.sender, transHistory.currentOwner, currentOwnerPortion);
    require(isSuccess);
    //console.log("buyToken, decreaseAllowance tokenOwner, isSuccess=%s", isSuccess);   

    //console.log("buyToken, safeTransferFrom, tokenOwner=%s, msg.sender=%s, nftToken.owner()=%s", tokenOwner, msg.sender, nftToken.owner());  
    // transfer the token from owner to the caller of the function (buyer)

    balanceForBuyer = erc20Token.balanceOf(msg.sender); //buyer's balance
    balanceForTokenOwner = erc20Token.balanceOf(tokenOwner); //company's balance   
    //console.log("buyToken, afterBalanceForBuyer3=%s, afterBalanceForTokenOwner=%s",  balanceForBuyer, balanceForTokenOwner);


    allUsersTokenIds[msg.sender].push(_tokenId);
    //console.log("buyToken, COMPLETE Bying, allUsersTokenIds[msg.sender].length2=%s", allUsersTokenIds[msg.sender].length);  

    //uint256[] storage preOwner = allUsersTokenIds[tokenOwner];
    //console.log("buyToken, COMPLETE Bying, preOwner.length1=%s", preOwner.length);  
    for (uint i = 0; i < allUsersTokenIds[tokenOwner].length; ++i) 
    {
        if(allUsersTokenIds[tokenOwner][i] == _tokenId)
        {
            allUsersTokenIds[tokenOwner][i] = allUsersTokenIds[tokenOwner][allUsersTokenIds[tokenOwner].length - 1];
            allUsersTokenIds[tokenOwner].pop();
            break;
        }
    }
    //console.log("buyToken, COMPLETE Bying, preOwner.length2=%s", preOwner.length);  

    //console.log("buyToken, before transfer token, _tokenId=%s, nftToken.owner()=%s",  _tokenId, isApproved, nftToken.owner());
    //require(isApproved2, "not allowed to transfer");
    nftToken.transferFrom(nftToken.owner(), msg.sender, _tokenId);
    //console.log("buyToken, isSucces2");  

    transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = msg.sender;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].companyFee = companyPortion;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].ownerFee = currentOwnerPortion;
    transHistory.purchaseInfoList[transHistory.numberOfTransfers].endDate = block.timestamp; 

    //console.log("buyToken, transHistory.tokenId=%s", transHistory.tokenId);  
    //console.log("buyToken, transHistory.numberOfTransfers=%s", transHistory.numberOfTransfers);  
    //console.log("buyToken, transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller);      
    //console.log("buyToken, transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer);  
    //console.log("buyToken, transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice);      
    //console.log("buyToken, transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice);  
    //console.log("buyToken, transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate);  
    //console.log("buyToken, transHistory.purchaseInfoList[transHistory.numberOfTransfers].endDate=%s", transHistory.purchaseInfoList[transHistory.numberOfTransfers].endDate);  

    emit OnBuyToken(_tokenId, msg.sender, transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice, transHistory.numberOfTransfers);    

    transHistory.currentOwner = msg.sender;
    transHistory.currentPrice = transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice;
    transHistory.numberOfTransfers += 1;
    transHistory.forSale = false;

    //console.log("buyToken, COMPLETE Bying, transHistory.tokenId=%s", transHistory.tokenId);  
    //console.log("buyToken, COMPLETE Bying, transHistory.numberOfTransfers=%s", transHistory.numberOfTransfers);  
    //console.log("buyToken, COMPLETE Bying, transHistory.currentOwner=%s", transHistory.currentOwner);  
    //console.log("buyToken, COMPLETE Bying, transHistory.currentPrice=%s", transHistory.currentPrice);  
    //console.log("buyToken, COMPLETE Bying, transHistory.forSale=%s", transHistory.forSale);  

    return true;
  }
}