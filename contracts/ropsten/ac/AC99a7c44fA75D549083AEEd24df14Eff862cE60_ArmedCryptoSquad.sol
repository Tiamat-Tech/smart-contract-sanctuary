// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ArmedCryptoSquad is
    ERC721Enumerable,
    AccessControl
{  
    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");

    uint256 private  _maxTotal;
    uint256 private  _batchSize;
    string private constant _uriExtension = "json";

    uint256 private _maxAmountPerMint = 10;
    uint256 private _maxAmountPerMintPresale = 4;
    uint256 private _reservedMints = 100;         
    uint256 private _currentBatchID = 0;
    
    uint256 private _cost = 0.07 ether;
    uint256 private _presaleCost = 0.055 ether;
    
    bool private _initialBatchIsSet;
    bool private _isPaused = true;

    mapping(uint256 => string) private _batchCIDs;

    mapping(address => bool) private _whitelist;

    mapping(uint256 => mapping(address => bool)) private _presaleMinted;

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
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TEAM_ROLE, msg.sender);

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
        uint256 batchNumber = tokenId / _batchSize;
        require(bytes(_batchCIDs[batchNumber]).length != 0, "Invalid tokenId");
        return _batchCIDs[batchNumber];
    }

    //Transactions

    function mint(uint256 amount) public payable { 
        require(!_isPresale, "its currently only for Whitelisted users");
        _commonMint(msg.sender, amount, _cost);       
    }

    function mintPresale(uint256 amount) public payable {
        require(_isPresale, "currently only for Whitelisted users");
        require(isWhitelisted(msg.sender), "mint is currently on Presale, but address is not whitelisted");
        require(!(_presaleMinted[_currentBatchID][msg.sender]), "User already minted in Presale");
        _commonMint(msg.sender, amount, _presaleCost);
        _presaleMinted[_currentBatchID][msg.sender] = true;
    }

    function airDrop(address[] memory addresses) public onlyRole(TEAM_ROLE) {
        require(_initialBatchIsSet, "initial batch is not set");
        require(_reservedMints > 0, "no reserved mints available");
        require((totalSupply() + addresses.length) <= (_maxTotal - _reservedMints), "You would exceed the limit");
        require(totalSupply() < ((_currentBatchID+1)*_batchSize), "current batch supply is exceeded"); 

        uint256 id = totalSupply();
        for (uint256 i = 0; i < addresses.length; i++) {
            id++;
            _safeMint(addresses[i], id);
            emit Mint(msg.sender, totalSupply());
            _reservedMints--;   
        }
    }

    function withdraw(address payable to, uint256 amount) public onlyRole(TEAM_ROLE) {
        to.transfer(amount);
    }

    function _commonMint(address to, uint256 amount, uint256 cost) internal {
        require(!_isPaused, "mint is currently paused");
        require(_initialBatchIsSet, "initial batch is not set");
        require(amount > 0, "need to mint at least 1");
        require(amount <= _maxAmountPerMint, "max amount per mint is exceeded");
        require(totalSupply() < ((_currentBatchID+1)*_batchSize), "current batch supply is exceeded");
        require((amount + totalSupply()) < (_maxTotal - _reservedMints), "total supply is exceeded");
        require(msg.value >= (cost * amount), "insufficient funds");

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
        if (_isPresale) {
            return _presaleCost;
        } else {
        return _cost;
        }
        
    }

    function getAmontPerMint() public view returns (uint256) {
        if (_isPresale) {
            return _maxAmountPerMintPresale;
        } else {
            return _maxAmountPerMint;
        }
    }

    function isPresale() public view returns (bool) {
        return _isPresale;
    }

    function isPaused() public view returns (bool) {
        return _isPaused;
    }

    // Setters (onlyOwner)

    function initialBatch(string memory CIDPath) public onlyRole(TEAM_ROLE) {
        _batchCIDs[_currentBatchID] = CIDPath;
        _initialBatchIsSet = true;
    }

    function registerNewBatch(string memory CIDPath, uint256 reservedMints) public onlyRole(TEAM_ROLE) {
        _currentBatchID++;
        _batchCIDs[_currentBatchID] = CIDPath;
        _reservedMints = reservedMints;
    }

    function revealBatch(uint256 barchNr, string memory CIDPath) public onlyRole(TEAM_ROLE) {
        _batchCIDs[barchNr] = CIDPath;
    }

    function addAddressesToWhitelist(address[] memory addresses) public onlyRole(TEAM_ROLE) {
        for (uint256 i = 0; i < _whitelistArray.length; i++) {
            _whitelist[_whitelistArray[i]] = false;
        }
        for (uint256 i = 0; i < addresses.length; i++) {
            _whitelist[addresses[i]] = true;
        }
        _whitelistArray = addresses;
    }

    function setPresale(bool enable) public onlyRole(TEAM_ROLE) {
        _isPresale = enable;
    }

    function setCost(uint256 newCost) public onlyRole(TEAM_ROLE) {
        _cost = newCost;
    }

    function setPresaleCost(uint256 newCost) public onlyRole(TEAM_ROLE) {
        _presaleCost = newCost;
    }

    function setMaxAmountPerMint(uint256 amount) public onlyRole(TEAM_ROLE) {
        _maxAmountPerMint = amount;
    }

    function setPaused(bool value) public onlyRole(TEAM_ROLE) {
        _isPaused = value;
    }

    function setReservedMints(uint256 count) public onlyRole(TEAM_ROLE) {
        _reservedMints = count;
    }

    function setBaseTokenURI(string memory url) public onlyRole(TEAM_ROLE) {
        _baseTokenURI = url;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}