// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ArmedCryptoSquad is
    ERC721Enumerable,
    Ownable
{  
    uint256 private  _maxTotal;
    uint256 private  _batchSize;
    string private constant _uriExtension = "json";

    uint256 private _maxAmountPerMint = 10;
    uint256 private _reservedMints = 10;         
    uint256 private _currentBatchID = 0;
    
    uint256 private _cost = 0.07 ether;
    uint256 private _presaleCost = 0.055 ether;
    
    bool private _initialBatchIsSet;
    bool private _isPaused = true;

    mapping(uint256 => string) private _batchCIDs;

    mapping(address => bool) private _whitelist;

    bool private _isPresale = true;
    address[] private _whitelistArray;
    string private _baseTokenURI;

    event Mint(address indexed sender, uint totalSupply);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint256 maxTotal,
        uint256 batchSize,
        uint256 reservedMints
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        _maxTotal = maxTotal;
        _batchSize = batchSize;
        _reservedMints = reservedMints;
    }

    // Metadata

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(_baseURI(),_tokenURIforBatch(tokenId), "/", Strings.toString(tokenId), ".", _uriExtension));
    }
    
    function _tokenURIforBatch(uint256 tokenId) internal view returns (string memory) {
        require(tokenId <= _maxTotal, "Invalid tokenId");
        // require(tokenId <= totalSupply(), "token is not minted yet"); // issues to test
        uint256 batchNumber = (tokenId-1) / _batchSize;
        require(bytes(_batchCIDs[batchNumber]).length != 0, "Invalid tokenId");
        return _batchCIDs[batchNumber];
    }

    //Transactions

    function mint(address to, uint256 amount) public payable {
        require(!_isPresale, "its currently only for Whitelisted users");
        _mint(to, amount, _cost);       
    }

    function mintPresale(address to, uint256 amount) public payable {
        require(_isPresale, "currently only for Whitelisted users");
        require(isWhitelisted(to), "mint is currently on Presale, but address is not whitelisted");
        _mint(to, amount, _presaleCost);
    }

    function mintReserved(address to) public onlyOwner {
        require(_initialBatchIsSet, "initial batch is not set");
        require(_reservedMints > 0, "no reserved mints available");
        require(totalSupply() < _maxTotal, "total supply is exceeded");
        require(totalSupply() < ((_currentBatchID+1)*_batchSize), "current batch supply is exceeded"); 
        uint256 id = totalSupply() + 1;
        _safeMint(to, id);
        emit Mint(msg.sender, totalSupply());
        _reservedMints--;   
    }

    function airDrop(address[] memory addresses) public onlyOwner {
        require(_initialBatchIsSet, "initial batch is not set");
        require((totalSupply() + addresses.length) <= (_maxTotal - _reservedMints), "You would exceed the limit");
        require(totalSupply() < ((_currentBatchID+1)*_batchSize), "current batch supply is exceeded"); 

        uint256 id = totalSupply();
        for (uint256 i = 0; i < addresses.length; i++) {
            id++;
            _safeMint(addresses[i], id);
            emit Mint(msg.sender, totalSupply());
        }
    }

    function withdraw(address payable to, uint256 amount) public onlyOwner {
        to.transfer(amount);
    }

    function _mint(address to, uint256 amount, uint256 cost) internal {
        require(msg.value >= cost * amount, "insufficient funds");
        require(!_isPaused, "mint is currently paused");
        require(_initialBatchIsSet, "initial batch is not set");
        require(amount > 0, "need to mint at least 1");
        require(amount <= _maxAmountPerMint, "max amount per mint is exceeded");
        require(totalSupply() < ((_currentBatchID+1)*_batchSize), "current batch supply is exceeded");
        require((amount + totalSupply()) < (_maxTotal - _reservedMints), "total supply is exceeded");
        require(msg.value >= (_cost * amount), "insufficient funds");

        uint256 id = totalSupply();
        for (uint256 i = 0; i < amount; i++) {  
            id++;
            _safeMint(to, id);
            emit Mint(msg.sender, totalSupply());
        } 
    }
    
    // Getters 

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelist[account];
    }

    function getPresaleCost() public view returns (uint256) {
        return _presaleCost;
    }

    function getCost() public view returns (uint256) {
        return _cost;
    }

    // Setters (onlyOwner)

    function initialBatch(string memory CIDPath) public onlyOwner {
        _batchCIDs[_currentBatchID] = CIDPath;
        _initialBatchIsSet = true;
    }

    function registerNewBatch(string memory CIDPath) public onlyOwner {
        _currentBatchID++;
        _batchCIDs[_currentBatchID] = CIDPath;
    }

    function revealCurrentBatch(string memory CIDPath) public onlyOwner {
        _batchCIDs[_currentBatchID] = CIDPath;
    }

    function addAddressesToWhitelist(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < _whitelistArray.length; i++) {
            _whitelist[_whitelistArray[i]] = false;
        }
        for (uint256 i = 0; i < addresses.length; i++) {
            _whitelist[addresses[i]] = true;
        }
        _whitelistArray = addresses;
    }

    function setPresale(bool enable) public onlyOwner {
        _isPresale = enable;
    }

    function setCost(uint256 newCost) public onlyOwner {
        _cost = newCost;
    }

    function setPresaleCost(uint256 newCost) public onlyOwner {
        _presaleCost = newCost;
    }

    function setMaxAmountPerMint(uint256 amount) public onlyOwner {
        _maxAmountPerMint = amount;
    }

    function setPaused(bool value) public onlyOwner {
        _isPaused = value;
    }
}