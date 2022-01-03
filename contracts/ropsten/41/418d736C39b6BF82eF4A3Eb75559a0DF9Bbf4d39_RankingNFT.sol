//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.3;

//import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol";
//import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "./RankingERC20Token.sol";

/*
import "hardhat/console.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC721/IERC721Metadata.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC721/IERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC721/IERC721Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/introspection/ERC165.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/Address.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/EnumerableSet.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/EnumerableMap.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/Strings.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SignedSafeMath.sol";
import "./RankingERC20Token.sol";
*/

contract RankingNFT is ERC165, IERC721, IERC721Metadata, Ownable, Pausable {

    event OnMintNFT(address indexed _recipient, string indexed _tokenURI, uint256 indexed _newItemId);

    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    using SignedSafeMath for int256;
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint256;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURI;

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;
	

	//////////////////////////////////////////////////////////////////////
	//For Trade
	address public creatorAddress;
    RankingERC20Token public erc20Token;
	
    event OnMyMintNFT(address indexed _actualMinter, string indexed _tokenURI, uint256 _newItemId, uint256 _initERC20Price);
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
	
    constructor (RankingERC20Token _erc20Token) {
        _name = "RankingNFT";
        _symbol = "RANKNFT";
		
        creatorAddress = msg.sender;
        erc20Token = _erc20Token;	

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    function mintNFT(address _recipient, string memory _tokenURI) private returns (uint256) {

        //console.log("mintNFT, Sender=%s, _recipient=%s, _tokenURI=%s", msg.sender, _recipient, _tokenURI);

        tokenIds.increment();

        uint256 newItemId = tokenIds.current();
        //console.log("mintNFT, newItemId=%s", newItemId);
        
        _mint(_recipient, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        emit OnMintNFT(_recipient, _tokenURI, newItemId);

        //console.log("mintNFT, Sender=%s, _recipient=%s, newItemId=%s", msg.sender, _recipient, newItemId);        

        // returns the id for the newly created token
        return newItemId;
    }    

    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _holderTokens[owner].length();
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];

        // If there is no base URI, return the token URI.
        if (bytes(_baseURI).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(_baseURI, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(_baseURI, tokenId.toString()));
    }

    function baseURI() internal view returns (string memory) {
        return _baseURI;
    }

    function totalSupply() public view returns (uint256) {
        return tokenIds.current();
    }

    function approve(address to, uint256 tokenId) external virtual override {
    }

    function getApproved(uint256 tokenId) external view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external virtual override {
    }

    function mySetApprovalForAll(address sender, address operator, bool approved) private {
        //console.log("mySetApprovalForAll, sender=%s, operator=%s, approved=%s", sender, operator, approved);

        require(operator != sender, "ERC721: approve to caller");

        _operatorApprovals[sender][operator] = approved;

        //console.log("mySetApprovalForAll, sender=%s, operator=%s, _operatorApprovals[sender][operator]=%s", sender, operator, _operatorApprovals[sender][operator]);

        emit ApprovalForAll(sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
    }

    function myisApprovedForAll(address owner, address operator) private view returns (bool) {
        bool result = _operatorApprovals[owner][operator];
        //console.log("myisApprovedForAll, owner=%s, operator=%s, result=%s", owner, operator, result);
        return result;
    }    

    function transferFrom(address from, address to, uint256 tokenId) external override {
    }

    function myTransferFrom(address from, address to, uint256 tokenId) private {

        //console.log("transferFrom, from=%s, to=%s, tokenId=%s", from, to, tokenId);
        //solhint-disable-next-line max-line-length
        //require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        require(_isApprovedOrOwner(from, tokenId), "ERC721: transfer caller is not owner nor approved");

        //console.log("transferFrom, 2from=%s, to=%s, tokenId=%s", from, to, tokenId);
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external virtual override {
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external virtual override {
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) private {
    }

    function _exists(uint256 tokenId) private view returns (bool) {
        return _tokenOwners.contains(tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) private view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = this.ownerOf(tokenId);
        return (spender == owner || this.getApproved(tokenId) == spender || myisApprovedForAll(owner, spender));
    }

    /*
    function _safeMint(address to, uint256 tokenId) private {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(address to, uint256 tokenId, bytes memory _data) private {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }
    */

    function _mint(address to, uint256 tokenId) private {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);
        _holderTokens[to].add(tokenId);
        _tokenOwners.set(tokenId, to);

        emit Transfer(address(0), to, tokenId);
    }

     function _burn(uint256 tokenId) external virtual {
        address owner = this.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        // Clear metadata (if any)
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }

        _holderTokens[owner].remove(tokenId);

        _tokenOwners.remove(tokenId);

        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) private {
        //console.log("_transfer, from=%s, to=%s, tokenId=%s", from, to, tokenId);

        require(this.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        //console.log("_transfer, 2from=%s, to=%s, tokenId=%s", from, to, tokenId);

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) private {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _setBaseURI(string memory baseURI_) private {
        _baseURI = baseURI_;
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(abi.encodeWithSelector(
            IERC721Receiver(to).onERC721Received.selector,
            _msgSender(),
            from,
            tokenId,
            _data
        ), "ERC721: transfer to non ERC721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _ERC721_RECEIVED);
    }

    function _approve(address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(this.ownerOf(tokenId), to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) private { }    
	
		
	//////////////////////////////////////////////////////////////////////////////////////////////////
	//For Trade
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

        uint256 newItemId = mintNFT(msg.sender, _tokenURI);
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

        emit OnMyMintNFT(msg.sender, _tokenURI, newItemId, _initERC20Price);

        // returns the id for the newly created token
        return newItemId;
  }

  // get balance of ERC20
  function getBalanceOfERC20(address _userAddress) public view returns(uint256) {
    return erc20Token.balanceOf(_userAddress);
  }    

  // get all user's token ids
  function getAllUserTokenIds(address _userAddress) public view returns(uint256[] memory) {
    uint256[] memory list = allUsersTokenIds[_userAddress];
    return list;
  }   

  // get owner of the token
  function getNFTOwner(uint256 _tokenId) public view returns(address) {
    address _tokenOwner = this.ownerOf(_tokenId);
    return _tokenOwner;
  }    

  // get metadata of the token
  function getNFTMetaData(uint _tokenId) public view returns(string memory) {
    string memory tokenMetaData = this.tokenURI(_tokenId);
    return tokenMetaData;
  }  

  // check if the token already exists
  function getNFTExists(uint256 _tokenId) public view returns(bool) {
    string memory tokenMetaData = this.tokenURI(_tokenId);
    bool tokenExists = (bytes(tokenMetaData).length >= MIN_INPUT_TOKEN_URL_SIZE) ? true : false;
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
    require(msg.sender != address(0));

    //console.log("setForSaleWithGoalPrice, _tokenId=%s, getNFTExists(_tokenId)=%s",  _tokenId, getNFTExists(_tokenId));

    // require that token should exist
    require(getNFTExists(_tokenId));

    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];

    // get the token's owner
    address tokenOwner = transHistory.currentOwner;

    require(tokenOwner == msg.sender);    

    //console.log("setForSaleWithGoalPrice, _tokenId=%s, transHistory.numberOfTransfers=%s, _isForSale=%s",  _tokenId, transHistory.numberOfTransfers, _isForSale);
    if(_isForSale) //For Sale
    {
        require(_goalPrice >= FEE_MINT_FOR_COMPANY && _goalPrice <= MAX_PRICE, "goalPrice must be bigger than 1000 token");

        //console.log("setForSaleWithGoalPrice, true, _tokenId=%s, owner()=%s",  _tokenId, owner());
        transHistory.forSale = true;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller = tokenOwner;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = address(0);
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice = _goalPrice;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].companyFee = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].ownerFee = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate = block.timestamp;     
        mySetApprovalForAll(msg.sender, owner(), true);

        bool isApproved1 = myisApprovedForAll(msg.sender, owner());
        //console.log("setForSaleWithGoalPrice, true, _tokenId=%s, isApproved1=%s, owner()=%s",  _tokenId, isApproved1, owner());
        require(isApproved1, "not allowed to transfer");
        myTransferFrom(msg.sender, owner(), _tokenId);

    }
    else //To stop sale
    {
        require(_goalPrice <= MIN_PRICE, "goalPrice must be 0" );

        //console.log("setForSaleWithGoalPrice, false, _tokenId=%s, owner()=%s",  _tokenId, owner());
        transHistory.forSale = false;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].seller = tokenOwner;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].buyer = address(0);
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].finalPrice = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].companyFee = 0;
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].ownerFee = 0;        
        transHistory.purchaseInfoList[transHistory.numberOfTransfers].startDate = 0;

        myTransferFrom(owner(), msg.sender, _tokenId);       
        mySetApprovalForAll(msg.sender, owner(), false);   

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

    
    TransactionHistory storage transHistory = allTransactionHistory[_tokenId];
    //console.log("buyToken, transHistory.numberOfTransfers=%s, transHistory.forSale=%s", transHistory.numberOfTransfers, transHistory.forSale);  

    // token should be for sale
    require(transHistory.forSale);

    // get the token's owner
    address tokenOwner = transHistory.currentOwner;
    //console.log("buyToken, msg.sender=%s, tokenOwner=%s", msg.sender, tokenOwner);      

    // token's owner should not be an zero address account
    require(tokenOwner != address(0));
    // the one who wants to buy the token should not be the token's owner
    require(tokenOwner != msg.sender);

    int256 tempFullPrice = int256(transHistory.purchaseInfoList[transHistory.numberOfTransfers].goalPrice);
    uint256 companyPortion = uint256(tempFullPrice.mul(int256(GENERAL_FEE_FOR_COMPANY)).div(1000));
    uint256 currentOwnerPortion = uint256(tempFullPrice.sub(int256(companyPortion)));
    //console.log("buyToken, tempGoalPrice=%s, companyPortion=%s, currentOwnerPortion=%s", uint256(tempFullPrice), uint256(companyPortion), uint256(currentOwnerPortion));

    uint256 balanceForBuyer = erc20Token.balanceOf(msg.sender); //buyer's balance
    //console.log("buyToken, balanceForBuyer=%s, uint256(tempFullPrice)=%s", balanceForBuyer, uint256(tempFullPrice));      
    require(balanceForBuyer >= uint256(tempFullPrice));

    //console.log("buyToken, balanceForBuyer=%s, companyPortion=%s", balanceForBuyer, companyPortion);      
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
    //console.log("buyToken, myTransfer msg.sender=%s, balanceForBuyer=%s", msg.sender, balanceForBuyer);  

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

    isSuccess = erc20Token.myTransfer(msg.sender, transHistory.currentOwner, currentOwnerPortion);
    require(isSuccess);        
    //console.log("buyToken, transfer tokenOwner, isSuccess=%s", isSuccess);  

    isSuccess = erc20Token.myDecreaseAllowance(msg.sender, transHistory.currentOwner, currentOwnerPortion);
    require(isSuccess);
    //console.log("buyToken, decreaseAllowance tokenOwner, isSuccess=%s", isSuccess);   

    //console.log("buyToken, safeTransferFrom, tokenOwner=%s, msg.sender=%s, owner()=%s", tokenOwner, msg.sender, owner());  

    // transfer the token from owner to the caller of the function (buyer)
    balanceForBuyer = erc20Token.balanceOf(msg.sender); //buyer's balance
    balanceForTokenOwner = erc20Token.balanceOf(transHistory.currentOwner); //current owner's balance
    //console.log("buyToken, afterBalanceForBuyer3=%s, afterBalanceForTokenOwner=%s",  balanceForBuyer, balanceForTokenOwner);

    allUsersTokenIds[msg.sender].push(_tokenId);
    //console.log("buyToken, COMPLETE Bying, allUsersTokenIds[msg.sender].length2=%s", allUsersTokenIds[msg.sender].length);  

    for (uint i = 0; i < allUsersTokenIds[transHistory.currentOwner].length; ++i) 
    {
        if(allUsersTokenIds[transHistory.currentOwner][i] == _tokenId)
        {
            allUsersTokenIds[transHistory.currentOwner][i] = allUsersTokenIds[transHistory.currentOwner][allUsersTokenIds[transHistory.currentOwner].length - 1];
            allUsersTokenIds[transHistory.currentOwner].pop();
            break;
        }
    }

    //console.log("buyToken, before transfer token, _tokenId=%s, owner()=%s",  _tokenId, isApproved, owner());
    myTransferFrom(owner(), msg.sender, _tokenId);
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