// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ERC721{
    function batchMint(address to, uint256 numberOfNFTs) external;
}

interface ERC20{
    function decimals() external view returns(uint256);
    function transferFrom(address, address, uint256) external;
    function transfer(address, uint256) external;
}

contract RevogPrimaryMarketplace is Ownable, ReentrancyGuard{

//VARIABLES

    uint256 private constant ONEDAY = 1 days;
    uint256 private constant SEVENDAY = 7 days;
    uint256 private constant THIRTYDAY = 30 days;
    uint256 private constant RANGE = 10;
    uint256 private constant BASE_DECIMAL = 18;
    uint256 private constant DENOMINATOR = 100000;
    
    uint256 public maxBuyAllowed;
     
    mapping(address => bool) public supportedPriceTokens;
    address[] public supportedPriceTokensInternal;
  
    struct Sale {
        address buyer;
        uint256 boughtAt;
        uint256 price;
        uint256 totalUnits;
        address priceToken;
    }
    mapping(address => mapping(uint256 => Sale)) public sales;
    
    struct FeesDetail {
        bool status;
        mapping(address => uint256) collectedPerToken;
        mapping(address => uint256) withdrawalPerToken;
    }
    FeesDetail public feesDetail;
    uint256 public fees;
    
    struct ContractDetails {
        bool isWhitelisted;
        uint256 price;
        mapping(address => uint256) volumePerToken;
        mapping(address => uint256) feesPerToken;
        uint256 totalUnitsSold;
        uint256 totalSale;
        uint256 statusUpdatedAt;
        address priceToken;
        address author;
    }
    mapping(address => ContractDetails) public whitelistedContracts;
    address[] private whitelistedContractsInternal;
   
//EVENTS
    event PriceDetailsChanged(address nftContract, address changedBy, uint256 changedAt, uint256 newPrice, address priceTokendId);
    event AuthorChanged(address newAuthor, address nftContract, address changedBy, uint256 changedAt);
    event Buy(address nftContract, address buyer, uint256 boughtAt, uint256 price, uint256 totalUnits);
    event maxBuyAllowedChaned(uint256 newMaxBuyAllowed, address changedBy, uint256 changedAt);
    event WhitelistedContract(address nftContract, address author, uint256 price, address priceTokend, address whitestedBy, uint256 whitelistedAt);
    event BlacklistedContract(address nftContract, address whitestedBy, uint256 blacklistedAt);
    event PriceTokenAdded(address priceToken, address addedBy, uint256 addedAt);
    event PriceTokenDisabled(address priceToken, address disabledBy, uint256 disabledAt);
    event FeesChanged(uint256 newFees, address changedBy, uint256 changedAt);
    event FeesWithdrawal(address priceToken, uint256 amount, address withdrawalBy, uint256 withdrawalAt);
    
    constructor(uint256 _maxBuyAllowed, uint256 _fees){
        maxBuyAllowed = _maxBuyAllowed;
        supportedPriceTokens[address(0)] = true;
        supportedPriceTokensInternal.push(address(0));
        fees = _fees;
        emit PriceTokenAdded(address(0), msg.sender, block.timestamp);
        emit FeesChanged(_fees, msg.sender, block.timestamp);
        emit maxBuyAllowedChaned(_maxBuyAllowed, msg.sender, block.timestamp);
    }

//USER FUNCTIONS
    function buy(address _nftContract, uint256 _totalUnits) external nonReentrant() payable returns(bool){
        require(_totalUnits <= maxBuyAllowed, 'Invalid number of units' );
        ContractDetails storage contractDetails = whitelistedContracts[_nftContract];
        require(contractDetails.isWhitelisted, 'NFT contract is not whitelisted!!');
        address priceToken = contractDetails.priceToken;
        uint256 totalPrice = _totalUnits * contractDetails.price;
        uint256 feeAmount = totalPrice * fees / DENOMINATOR;
     
        contractDetails.volumePerToken[priceToken] = contractDetails.volumePerToken[priceToken] + totalPrice;
        contractDetails.feesPerToken[priceToken] = contractDetails.feesPerToken[priceToken] + feeAmount;
        contractDetails.totalUnitsSold = contractDetails.totalUnitsSold + _totalUnits;
        contractDetails.totalSale = contractDetails.totalSale + 1;
        
        Sale storage sale = sales[_nftContract][ contractDetails.totalSale];
        sale.price = contractDetails.price;
        sale.priceToken = priceToken;
        sale.boughtAt = block.timestamp;
        sale.buyer = msg.sender;
        sale.totalUnits = _totalUnits;
    
        feesDetail.collectedPerToken[priceToken] = feesDetail.collectedPerToken[priceToken] + feeAmount;
     
        if(priceToken== address(0)){
            require(msg.value >= totalPrice, 'amount paid is less than the total price of NFTs');
            uint256 extraAmountPaid = msg.value - totalPrice;
            payable(whitelistedContracts[_nftContract].author).transfer(totalPrice - feeAmount);
            if(extraAmountPaid > 0){
                payable(msg.sender).transfer(extraAmountPaid);
            }
        }else {
            ERC20(priceToken).transferFrom(msg.sender, address(this), convertValue(totalPrice, priceToken, false));
            ERC20(priceToken).transfer(whitelistedContracts[_nftContract].author, convertValue(totalPrice - feeAmount, priceToken, false));
        }
     
        ERC721(_nftContract).batchMint(msg.sender, _totalUnits);
        emit Buy(_nftContract, msg.sender, block.timestamp, totalPrice, _totalUnits);
        return true;
    }
  
//OWNER FUNCTIONS

    function whitelistContract(address _nftContract, address _author, uint256 _price, address _priceToken) external onlyOwner() returns(bool){
        require(_nftContract != address(0), 'Invalid contract address');
        require(_author != address(0), 'Invalid author');
        require(supportedPriceTokens[_priceToken], 'Price token not supported');
        require(!whitelistedContracts[_nftContract].isWhitelisted, 'Already whitelisred');
        whitelistedContracts[_nftContract].price = convertValue(_price, _priceToken, true);
        whitelistedContracts[_nftContract].priceToken = _priceToken;
        whitelistedContracts[_nftContract].isWhitelisted = true;
        whitelistedContracts[_nftContract].author = _author;
        whitelistedContracts[_nftContract].statusUpdatedAt = block.timestamp;
        if(whitelistedContracts[_nftContract].author == address(0)){
            whitelistedContractsInternal.push(_nftContract);
        }
        emit WhitelistedContract(_nftContract, _author, whitelistedContracts[_nftContract].price, _priceToken, msg.sender, block.timestamp);
        return true;
    }
    
    function updatePriceDetails(address _nftContract, uint256 _newPrice, address _newPriceToken) external onlyOwner() returns(bool){
        ContractDetails storage contractDetails = whitelistedContracts[_nftContract];
        require(contractDetails.isWhitelisted, 'NFT contract is not whitelisted!!');
        require(supportedPriceTokens[_newPriceToken], 'Price token not supported');
        contractDetails.price = convertValue(_newPrice, _newPriceToken, true) ;
        contractDetails.priceToken = _newPriceToken;
        emit PriceDetailsChanged(_nftContract, msg.sender, block.timestamp, _newPrice, _newPriceToken);
        return true;
    }
    
    function updateAuthor(address _nftContract, address _newAuthor) external onlyOwner() returns(bool){
        ContractDetails storage contractDetails = whitelistedContracts[_nftContract];
        require(contractDetails.isWhitelisted, 'NFT contract not whitelisted!!');
        require(_newAuthor != address(0), 'Invalid author');
        contractDetails.author = _newAuthor;
        emit AuthorChanged( _newAuthor, _nftContract, msg.sender, block.timestamp);
        return true;
    }
 
    function blacklistContract(address _nftContract) external onlyOwner() returns(bool){
        require(whitelistedContracts[_nftContract].isWhitelisted, 'Invalid contract');
        whitelistedContracts[_nftContract].isWhitelisted = false;
        whitelistedContracts[_nftContract].statusUpdatedAt = block.timestamp;
        emit BlacklistedContract(_nftContract, msg.sender, block.timestamp);
        return true;
    }
    
    function updateMaxBuyAllowed(uint256 _maxBuyAllowed) external onlyOwner() returns(bool){
        require(_maxBuyAllowed > 0, 'Max buy Allowed can not be zero');
        maxBuyAllowed = _maxBuyAllowed;
        emit maxBuyAllowedChaned(maxBuyAllowed, msg.sender, block.timestamp);
        return true;
    }

    function addPriceToken(address _newPriceToken) external onlyOwner() returns(bool){
        require(_newPriceToken != address(0), 'Invalid address');
        require(!supportedPriceTokens[_newPriceToken], 'Already added');
        supportedPriceTokens[_newPriceToken] = true;
        bool isPriceTokenExist = priceTokenExist(_newPriceToken);
        if(!isPriceTokenExist){
            supportedPriceTokensInternal.push(_newPriceToken);
        }
        emit PriceTokenAdded(_newPriceToken, msg.sender, block.timestamp);
        return true;
    }
    
    function disablePriceToken(address _priceToken) external onlyOwner() returns(bool){
        require(!supportedPriceTokens[_priceToken], 'Invalid price token');
        supportedPriceTokens[_priceToken] = false;
        emit PriceTokenDisabled(_priceToken, msg.sender, block.timestamp);
        return true;
    }
    
    function withdrawFees(address _priceToken) external onlyOwner() nonReentrant() returns(bool){
        uint256 availableFees = feesDetail.collectedPerToken[_priceToken] - feesDetail.withdrawalPerToken[_priceToken];
        require(availableFees > 0, 'Nothing to withdraw for this token');
        feesDetail.withdrawalPerToken[_priceToken] = feesDetail.withdrawalPerToken[_priceToken] + availableFees;
        if(_priceToken == address(0)){
            payable(msg.sender).transfer(availableFees);
        } else {
            ERC20(_priceToken).transfer(msg.sender, convertValue(availableFees, _priceToken, false));
        }
        emit FeesWithdrawal(_priceToken, availableFees, msg.sender, block.timestamp);
        return true;
    }
    
 
//VIEW FUNCTIONS
    function getSaleList(address _nftContract, uint256 _fromSaleId) external view returns(uint256, Sale[10] memory){
        uint256 toSaleId = whitelistedContracts[_nftContract].totalSale;
        if(toSaleId > _fromSaleId + RANGE){
            toSaleId = _fromSaleId + RANGE;
        }
        Sale[RANGE] memory saleList;
        uint8 totalSaleAdded = 0;
        for (uint256 i = _fromSaleId; i <= toSaleId; i++ ){
            Sale memory sale = sales[_nftContract][_fromSaleId];
            saleList[totalSaleAdded] = sale;
            totalSaleAdded++;
        }
        return (toSaleId, saleList);
    }
    
    function totalNFTSold(address _nftContract) external view returns(uint256, uint256, uint256){
        uint256 totalSoldLast24Hours = 0;
        uint256 totalSoldLast7Days = 0;
        uint256 totalSoldLast30Days = 0;
        uint256 currentTime = block.timestamp;
        for(uint256 i = whitelistedContracts[_nftContract].totalSale; i >= 1; i--){
            Sale memory sale = sales[_nftContract][i];
            if(sale.boughtAt < currentTime - THIRTYDAY ){
                break;
            }
            if(sale.boughtAt >= currentTime - ONEDAY){
                totalSoldLast24Hours = totalSoldLast24Hours + 1;
            } 
            if(sale.boughtAt >= currentTime - SEVENDAY){
                totalSoldLast7Days = totalSoldLast7Days + 1;
            } 
            if(sale.boughtAt >= currentTime - THIRTYDAY){
                totalSoldLast30Days = totalSoldLast30Days + 1;
            }
        }
        return (totalSoldLast24Hours, totalSoldLast7Days, totalSoldLast30Days);
    }

    function priceTokensList() external view returns(address[] memory){
        return supportedPriceTokensInternal;
    }

    function getNFTContracts() external view returns(address[] memory){
        return whitelistedContractsInternal;
    }
    
    
//INTERNAL FUNCTIONS
    receive() payable external{
        
    }
    
    function convertValue(uint256 _value, address _priceToken, bool _toBase) internal view returns(uint256){
        if(_priceToken == address(0) || ERC20(_priceToken).decimals() == BASE_DECIMAL){
            return _value;
        }
        uint256 decimals = ERC20(_priceToken).decimals();
        if(_toBase){
            return _value * 10**(BASE_DECIMAL - decimals);
        } else {
            return _value / 10**(BASE_DECIMAL - decimals);
        }
    }
        
    function priceTokenExist(address _priceToken) internal view returns(bool){
        for(uint index = 0; index < supportedPriceTokensInternal.length; index++){
            if(supportedPriceTokensInternal[index] == _priceToken){
                return true;
            }
        }
        return false;
    }
}