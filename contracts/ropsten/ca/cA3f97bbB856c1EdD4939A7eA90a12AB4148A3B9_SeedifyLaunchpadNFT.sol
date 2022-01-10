// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC1155/ERC1155.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/security/Pausable.sol";
import "@openzeppelin/[email protected]/token/ERC1155/extensions/ERC1155Burnable.sol";
interface Market {
    function placeOrder(address _creator, uint256 _tokenId, uint256 _editions,
        uint256 _pricePerNFT, uint256 _saleType, uint256 _startTime) external;
}
// Seedify NFT lanchpad smartcontract
contract SeedifyLaunchpadNFT is ERC1155, Ownable, Pausable, ERC1155Burnable {
    constructor() ERC1155("") {}

    // address array for whitelist
    address[] private whitelist; 
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

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }


    function mintAndPassToMarketPlace(address account, uint256 _editions,uint256 _pricePerNFT,uint256 _saleType, uint256 _startTime)
        public
    {        
        require(checkWhitelist(msg.sender), "You are not eligible to Mint item");
        
        tokenIDs = tokenIDs + 1;
        _mint(account, tokenIDs, _editions, "0x00");
        Market(marketPlaceAddress).placeOrder(account, tokenIDs, _editions, _pricePerNFT, _saleType, _startTime);    
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
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
}