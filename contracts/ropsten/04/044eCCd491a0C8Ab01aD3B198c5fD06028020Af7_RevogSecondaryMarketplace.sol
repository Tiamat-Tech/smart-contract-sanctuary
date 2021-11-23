// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ERC721{
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface ERC20{
    function decimals() external view returns(uint256);
    function transferFrom(address, address, uint256) external;
    function transfer(address, uint256) external;
}

contract RevogSecondaryMarketplace is Ownable, ReentrancyGuard{

//VARIABLES

    uint256 private constant DENOMINATOR = 10000;
    uint256 private constant BASE_DECIMAL = 18;
    uint256 public fees;   
    
    enum Status{ Sold, UnSold, Removed } 
    struct Sale {
        address seller;
        address buyer;
        uint256 nftId;
        uint256 listedAt;
        uint256 price;
        uint256 fees;
        uint256 authorFees;
        address priceToken;
        Status status;
    }
    //nftContract => saleId
    mapping(address => mapping(uint256 => Sale)) public sales;
    
    struct FeesDetail {
        bool status;
        mapping(address => uint256) collectedPerToken;
        mapping(address => uint256) withdrawalPerToken;
    }
    FeesDetail private feesDetail;
    
    struct ContractDetails {
        bool isWhitelisted;
        address author;
        uint256 authorFees;
        mapping(address => uint256) volumePerToken;
        mapping(address => uint256) feesPerToken;
        uint256 totalSold;
        uint256 totalListed;
        uint256 totalRemoved;
    }
    mapping(address => ContractDetails) public whitelistedContracts;
    address[] private whitelistedContractsInternal;
    
    struct SaleIdDetail {
        uint256[] allSaleIds;
        uint256 currentSaleId;
    }
    mapping(address => mapping(uint256 => SaleIdDetail)) public nftSaleIds;
    
    mapping(address => bool) public supportedPriceTokens;
    address[] internal supportedPriceTokensInternal;
    
//EVENTS
    event FeesChanged(uint256 newFee, address changedBy, uint256 time);
    event AddedToMarketplace(address nftContract, uint256 nftId, address seller, uint256 listedAt, uint256 price, uint256 fees, uint256 authorFees, uint256 saleId, address priceToken);
    event Buy(address nftContract, address buyer, uint256 saleId, uint256 boughtAt);
    event RemovedFromMarketplace(address nftContract, uint256 saleId);
    event PriceUpdated(address nftContract, uint256 saleId, uint256 price, address priceToken);
    event PriceTokenAdded(address priceToken, address addedBy, uint256 addedAt);
    event PriceTokenDisabled(address priceToken, address disabledBy, uint256 disabledAt);
    event WhitelistedContract(address nftContract, address author, uint256 authorFees, address whitelistedBy, uint256 whitelistedAt);
    event AuthorDetailsChanged(address nftContract, address author, uint256 authorFees, address changedBy, uint256 changedAt);
    event BlacklistedContract(address nftContract, address blacklistedBy, uint256 blacklistedAt);
    event FeesWithdrawal(address priceToken, uint256 amount, address withdrawalBy, uint256 withdrawalAt);
    
//CONSTRUCTOR
    constructor(uint256 _fees){
        require(fees <= DENOMINATOR, 'INVALID FEES');
        fees = _fees;
        supportedPriceTokens[address(0)] = true;
        supportedPriceTokensInternal.push(address(0));
        emit PriceTokenAdded(address(0), msg.sender, block.timestamp);
        emit FeesChanged(_fees, msg.sender, block.timestamp);
    }
    
//USER FUNCTIONS
    function addToMarketplace(address _nftContract, uint256 _nftId, uint256 _price, address _priceToken) external nonReentrant() returns(bool){
        require(supportedPriceTokens[_priceToken], 'Price token not supported');
        ContractDetails storage contractDetails = whitelistedContracts[_nftContract];
        require(contractDetails.isWhitelisted, 'NFT contract not whitelisted!!');
        uint256 currentSaleId = nftSaleIds[_nftContract][_nftId].currentSaleId;
        require(currentSaleId == 0, 'Already listed');
        uint256 saleId = contractDetails.totalListed + 1;
        Sale storage sale = sales[_nftContract][saleId];
        sale.nftId = _nftId;
        sale.seller = msg.sender;
        sale.listedAt = block.timestamp;
        sale.price = convertValue(_price, _priceToken, true);
        sale.fees = fees;
        sale.authorFees = contractDetails.authorFees;
        sale.priceToken = _priceToken;
        sale.status = Status.UnSold;
        nftSaleIds[_nftContract][_nftId].allSaleIds.push(saleId);
        nftSaleIds[_nftContract][_nftId].currentSaleId = saleId;
        contractDetails.totalListed = contractDetails.totalListed + 1;
        ERC721(_nftContract).transferFrom(msg.sender, address(this), _nftId);
        emit AddedToMarketplace(_nftContract, _nftId, msg.sender, sale.listedAt, sale.price, fees, contractDetails.authorFees, saleId, _priceToken);
        return true;
    }
    
    function removeFromMarketplace(address _nftContract, uint256 _nftId) external nonReentrant() returns(bool){
        uint256 saleId = nftSaleIds[_nftContract][_nftId].currentSaleId;
        require(saleId > 0, 'This NFT is not listed');
        Sale storage sale = sales[_nftContract][saleId];
        require(sale.seller == msg.sender, 'Only seller can remove');
        sale.status = Status.Removed;
        nftSaleIds[_nftContract][_nftId].currentSaleId = 0;
        whitelistedContracts[_nftContract].totalRemoved = whitelistedContracts[_nftContract].totalRemoved + 1;
        ERC721(_nftContract).transferFrom(address(this), sale.seller, _nftId);
        emit RemovedFromMarketplace(_nftContract, saleId);
        return true;
    }
    
    function buy(address _nftContract, uint256 _nftId) external nonReentrant() payable returns(bool){
        uint256 saleId = nftSaleIds[_nftContract][_nftId].currentSaleId;
        require(saleId > 0, 'This NFT is not listed');
        Sale storage sale = sales[_nftContract][saleId];
        ContractDetails storage contractDetails = whitelistedContracts[_nftContract];
        
        sale.status = Status.Sold;
        sale.buyer = msg.sender;

        nftSaleIds[_nftContract][_nftId].currentSaleId = 0;
        uint256 authorShare = sale.price * sale.authorFees / DENOMINATOR;
        uint256 marketPlaceFees = sale.price * sale.fees / DENOMINATOR;
        address priceToken = sale.priceToken;

        feesDetail.collectedPerToken[priceToken] = feesDetail.collectedPerToken[priceToken] + marketPlaceFees;
    
        contractDetails.volumePerToken[priceToken] = contractDetails.volumePerToken[priceToken] + sale.price;
        contractDetails.feesPerToken[priceToken] = contractDetails.feesPerToken[priceToken] + marketPlaceFees;
        contractDetails.totalSold = contractDetails.totalSold + 1;
      
        if(priceToken == address(0)){
            require(msg.value >= sale.price, 'amount paid is less than the price of NFT');
            uint256 extraAmountPaid = msg.value - sale.price;
            payable(sale.seller).transfer(sale.price - authorShare - marketPlaceFees);
            payable(contractDetails.author).transfer(authorShare);
            if(extraAmountPaid > 0){
                payable(msg.sender).transfer(extraAmountPaid);
            }
        } else {
            ERC20(priceToken).transferFrom(msg.sender, address(this), convertValue(sale.price, priceToken, false));
            ERC20(priceToken).transfer(contractDetails.author, convertValue(authorShare, priceToken, false));
            ERC20(priceToken).transfer(sale.seller, convertValue(sale.price - authorShare - marketPlaceFees, priceToken, false));
        }
        ERC721(_nftContract).transferFrom(address(this), msg.sender, _nftId);
        emit Buy(_nftContract, msg.sender, saleId, block.timestamp);
        return true;
    }
    
    function updatePrice(address _nftContract, uint256 _nftId, uint256 _newPrice, address _priceToken) external returns(bool){
        require(supportedPriceTokens[_priceToken], 'Price token not supported');
        uint256 saleId = nftSaleIds[_nftContract][_nftId].currentSaleId;
        require(saleId > 0, 'This NFT is not listed');
        Sale storage sale = sales[_nftContract][saleId];
        require(sale.seller == msg.sender, 'Only seller can update price');
        sale.priceToken = _priceToken;
        sale.price = convertValue(_newPrice, _priceToken, true);
        emit PriceUpdated(_nftContract, saleId, sale.price, _priceToken);
        return true;
    }
  
//OWNER FUNCTIONS

    function whitelistContract(address _nftContract, address _author, uint256 _authorFees) external onlyOwner() returns(bool){
        require(!whitelistedContracts[_nftContract].isWhitelisted, 'Already whitelisted');
        require(_nftContract != address(0), 'Invalid contract address');
        require(_author != address(0), 'Invalid author');
        require(_authorFees + fees <= DENOMINATOR, 'Invalid author fees');
        if(whitelistedContracts[_nftContract].author == address(0)){
            whitelistedContractsInternal.push(_nftContract);
        }
        whitelistedContracts[_nftContract].author = _author;
        whitelistedContracts[_nftContract].authorFees = _authorFees;
        whitelistedContracts[_nftContract].isWhitelisted = true;
        emit WhitelistedContract(_nftContract, _author, _authorFees, msg.sender, block.timestamp);
        return true;
    }
    
    function changeAuthorDetails(address _nftContract, address _author, uint256 _authorFees) external onlyOwner() returns(bool){
        require(whitelistedContracts[_nftContract].isWhitelisted, 'Not whitelisted, whitelist it with new details');
        require(_nftContract != address(0), 'Invalid contract address');
        require(_author != address(0), 'Invalid author');
        require(_authorFees + fees <= DENOMINATOR, 'Invalid author fees');
        whitelistedContracts[_nftContract].author = _author;
        whitelistedContracts[_nftContract].authorFees = _authorFees;
        emit AuthorDetailsChanged(_nftContract, _author, _authorFees, msg.sender, block.timestamp);
        return true;
    }
    
    function blacklistContract(address _nftContract) external onlyOwner() returns(bool){
        require(whitelistedContracts[_nftContract].author != address(0), 'Invalid contract');
        require(whitelistedContracts[_nftContract].isWhitelisted , 'Already blacklisted');
        whitelistedContracts[_nftContract].isWhitelisted = false;
        emit BlacklistedContract(_nftContract, msg.sender, block.timestamp);
        return true;
    }
    
    function updateFees(uint256 _newFees) external onlyOwner() returns(bool){
        require(checkFeesValid(_newFees), 'Invalid Fees');
        fees = _newFees;
        emit FeesChanged( _newFees, msg.sender, block.timestamp);
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
        require(supportedPriceTokens[_priceToken], 'Invalid price token');
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
    function NFTSaleDetail(address _nftContract, uint256 _nftId) external view returns(Sale memory){
        uint256 saleId = nftSaleIds[_nftContract][_nftId].currentSaleId;
        require(saleId > 0, 'This NFT is not listed');
        return sales[_nftContract][saleId];
    }

    function getFeesDetails(address _priceToken) external view returns(uint256, uint256){
        return (feesDetail.collectedPerToken[_priceToken], feesDetail.withdrawalPerToken[_priceToken]);
    }

    function getNFTContractPriceDetails(address _nftContract, address _priceToken) external view returns(uint256, uint256){
        return (whitelistedContracts[_nftContract].volumePerToken[_priceToken], whitelistedContracts[_nftContract].feesPerToken[_priceToken]);
    }
    
    function getAllSaleIds(address _nftContract, uint256 _nftId) external view returns(uint256[] memory){
        return nftSaleIds[_nftContract][_nftId].allSaleIds;
    }

    function priceTokensList() external view returns(address[] memory){
        return supportedPriceTokensInternal;
    }

    function getNFTContracts() external view returns(address[] memory){
        return whitelistedContractsInternal;
    }
    
    
//INTERNAL FUNCTIONS
    function checkFeesValid(uint256 _fees) internal view returns(bool){
        for(uint256 i = 0; i < whitelistedContractsInternal.length; i++){
            if(whitelistedContracts[whitelistedContractsInternal[i]].authorFees + _fees > DENOMINATOR){
                return false;
            }
        }
        return true;
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

    receive() payable external{}
}