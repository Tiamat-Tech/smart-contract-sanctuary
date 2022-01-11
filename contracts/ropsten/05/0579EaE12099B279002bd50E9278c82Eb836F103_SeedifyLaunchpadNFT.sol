// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC1155/ERC1155.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/security/Pausable.sol";
import "@openzeppelin/[email protected]/token/ERC1155/extensions/ERC1155Burnable.sol";
interface Market {
    function placeOrder(address _creator, uint256 _tokenId, uint256 _editions, uint256 _pricePerNFT, uint256 _saleType, uint256 _startTime)  external returns (bool);
    function importOrder(address _creator, uint256 _tokenId, uint256 _editions, uint256 _pricePerNFT, uint256 _saleType, uint256 _startTime)  external returns (bool);
}
// Seedify NFT lanchpad smartcontract
contract SeedifyLaunchpadNFT is ERC1155, Ownable, Pausable, ERC1155Burnable {
    constructor() ERC1155("https://launchpad.seedify.fund/") {}
    // mapping token uri
    mapping (uint256 => string) private _uris;
    // address array for whitelist
    address[] private whitelist; 
    // address array for tokens addresses
    address[] public tokenAddresses; 
    // MarketPlace address
    address public marketPlaceAddress;
    // token ids
    uint256 public tokenIDs;
    // setMarket place address
    function setMarketPlaceAddress(address _marketPlaceAddress) external onlyOwner returns (bool) {
        require(_marketPlaceAddress != address(0), "Zero address");
        marketPlaceAddress = _marketPlaceAddress;
        return true;
    }

    function mintAndPassToMarketPlace(address account, string memory _uri, bytes memory data, uint256 _editions,uint256 _pricePerNFT,uint256 _saleType, uint256 _startTime, address _paymentToken)
        public
        whenNotPaused
    {        
        require(checkWhitelist(msg.sender), "You are not eligible to Mint item");     
        require(checkTokenAddress(_paymentToken), "Invalid token address");    
        tokenIDs = tokenIDs + 1;
        _setTokenUri(tokenIDs, _uri);
        _mint(marketPlaceAddress, tokenIDs, _editions, data);
        Market(marketPlaceAddress).placeOrder(account, tokenIDs, _editions, _pricePerNFT, _saleType, _startTime);    
    }

    function importAndPassToMarketPlace(address _creator, uint256 _tokenId, string memory _uri, uint256 _editions, uint256 _pricePerNFT, uint256 _saleType, uint256 _startTime, address _paymentToken)
        public
        whenNotPaused
    {        
        require(checkWhitelist(msg.sender), "You are not eligible to Mint item");
        require(checkTokenAddress(_paymentToken), "Invalid token address"); 
        _setTokenUri(tokenIDs, _uri);
        Market(marketPlaceAddress).importOrder(_creator, _tokenId, _editions, _pricePerNFT, _saleType, _startTime);    
    }

    function _setTokenUri(uint256 tokenId, string memory uri) private {
        require(bytes(_uris[tokenId]).length == 0, "Cannot set the uri twice for a token");
        _uris[tokenId] = uri;
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        whenNotPaused
    {
        require(checkWhitelist(msg.sender), "You are not eligible to Mint item");
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        whenNotPaused
    {
        require(checkWhitelist(msg.sender), "You are not eligible to Mint items");
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

     //add the token address
    function addTokenAddress(address _address) public onlyOwner {
        require(_address != address(0), "Invalid address");
        tokenAddresses.push(_address);
    }

     // check the token address in the list
    function checkTokenAddress(address _address) public view returns(bool) {
        uint i;
        uint length = tokenAddresses.length;
        for (i = 0; i < length; i++) {
            address _addressArr = tokenAddresses[i];
            if (_addressArr == _address) {
                return true;
            }
        }
        return false;
    }

     // delete the token address from the list
    function deleteTokenAddress(address _address) public returns(bool) {
        uint i;
        uint length = tokenAddresses.length;
        for (i = 0; i < length; i++) {
            address _addressArr = tokenAddresses[i];
            if (_addressArr == _address) {
               delete tokenAddresses[i];
               return true;
            }
        }
        return false;
    }

     //add the address in Whitelist
    function addWhitelist(address _address) public onlyOwner {
        require(_address != address(0), "Invalid address");
        whitelist.push(_address);
    }

     // check the address in whitelist
    function checkWhitelist(address _address) public view returns(bool) {
        uint i;
        uint length = whitelist.length;
        for (i = 0; i < length; i++) {
            address _addressArr = whitelist[i];
            if (_addressArr == _address) {
                return true;
            }
        }
        return false;
    }
    
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}