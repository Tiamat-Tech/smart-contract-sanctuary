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

    uint256 private constant BASE_DECIMAL = 18;
    uint256 private constant DENOMINATOR = 10000;
    
    uint256 public maxBuyAllowed;
     
    mapping(address => bool) public supportedPriceTokens;
    address[] internal supportedPriceTokensInternal;
  
    struct Sale {
        address buyer;
        uint256 boughtAt;
        uint256 price;
        uint256 fees;
        uint256 feesAmount;
        uint256 totalUnits;
        address priceToken;
    }
    mapping(address => mapping(uint256 => Sale)) public sales;
    
    struct FeesDetail {
        bool status;
        mapping(address => uint256) collectedPerToken;
        mapping(address => uint256) withdrawalPerToken;
    }
    FeesDetail private feesDetail;
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
    event Buy(address nftContract, address buyer, uint256 boughtAt, uint256 price, uint256 totalUnits, uint256 fees, address priceToken);
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
        uint256 feesAmount = totalPrice * fees / DENOMINATOR;
     
        contractDetails.volumePerToken[priceToken] = contractDetails.volumePerToken[priceToken] + totalPrice;
        contractDetails.feesPerToken[priceToken] = contractDetails.feesPerToken[priceToken] + feesAmount;
        contractDetails.totalUnitsSold = contractDetails.totalUnitsSold + _totalUnits;
        contractDetails.totalSale = contractDetails.totalSale + 1;
        
        Sale storage sale = sales[_nftContract][ contractDetails.totalSale];
        sale.price = contractDetails.price;
        sale.priceToken = priceToken;
        sale.boughtAt = block.timestamp;
        sale.buyer = msg.sender;
        sale.totalUnits = _totalUnits;
        sale.fees = fees;
        sale.feesAmount = feesAmount;
    
        feesDetail.collectedPerToken[priceToken] = feesDetail.collectedPerToken[priceToken] + feesAmount;
     
        if(priceToken== address(0)){
            require(msg.value >= totalPrice, 'amount paid is less than the total price of NFTs');
            uint256 extraAmountPaid = msg.value - totalPrice;
            payable(whitelistedContracts[_nftContract].author).transfer(totalPrice - feesAmount);
            if(extraAmountPaid > 0){
                payable(msg.sender).transfer(extraAmountPaid);
            }
        }else {
            ERC20(priceToken).transferFrom(msg.sender, address(this), convertValue(totalPrice, priceToken, false));
            ERC20(priceToken).transfer(whitelistedContracts[_nftContract].author, convertValue(totalPrice - feesAmount, priceToken, false));
        }
     
        ERC721(_nftContract).batchMint(msg.sender, _totalUnits);
        emit Buy(_nftContract, msg.sender, block.timestamp, totalPrice, _totalUnits, fees, priceToken);
        return true;
    }
  
//OWNER FUNCTIONS

    function whitelistContract(address _nftContract, address _author, uint256 _price, address _priceToken) external onlyOwner() returns(bool){
        require(_nftContract != address(0), 'Invalid contract address');
        require(_author != address(0), 'Invalid author');
        require(supportedPriceTokens[_priceToken], 'Price token not supported');
        require(!whitelistedContracts[_nftContract].isWhitelisted, 'Already whitelisred');
        if(whitelistedContracts[_nftContract].author == address(0)){
            whitelistedContractsInternal.push(_nftContract);
        }
        whitelistedContracts[_nftContract].price = convertValue(_price, _priceToken, true);
        whitelistedContracts[_nftContract].priceToken = _priceToken;
        whitelistedContracts[_nftContract].isWhitelisted = true;
        whitelistedContracts[_nftContract].author = _author;
        whitelistedContracts[_nftContract].statusUpdatedAt = block.timestamp;
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
    
    function updateFees(uint256 _newFees) external onlyOwner() returns(bool){
        fees = _newFees;
        emit FeesChanged( _newFees, msg.sender, block.timestamp);
        return true;
    }
 
//VIEW FUNCTIONS
    function priceTokensList() external view returns(address[] memory){
        return supportedPriceTokensInternal;
    }

    function getNFTContracts() external view returns(address[] memory){
        return whitelistedContractsInternal;
    }

    function getFeesDetails(address _priceToken) external view returns(uint256, uint256){
        return (feesDetail.collectedPerToken[_priceToken], feesDetail.withdrawalPerToken[_priceToken]);
    }

    function getNFTContractPriceDetails(address _nftContract, address _priceToken) external view returns(uint256, uint256){
        return (whitelistedContracts[_nftContract].volumePerToken[_priceToken], whitelistedContracts[_nftContract].feesPerToken[_priceToken]);
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