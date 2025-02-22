// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CryptoHackers is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    Counters.Counter private _tokenIds;
    
    constructor() ERC721("CryptoHackers", "HACKERZ") {
        _tokenIds.increment();
    }
    
    mapping (uint256 => address) previousOwner;
    mapping (uint256 => address) firstOwner;
    
    uint256 private tokenPrice = 50000000000000000; // 0.05 Eth
    uint256 private maxCap = 7134; // (7132 + 2)
    string public baseUri = "ipfs://QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn";
    
    bool salesIsOpen = false;
    bool metadataLocked = false;

    function SafeMint(uint256 amountToMint) public payable {
        require(salesIsOpen == true, "Sales is not open");
        uint256 currentToken = _tokenIds.current();
        require(amountToMint < 11, "Can't mint too much at once!");
        require(currentToken + amountToMint < maxCap, "Limit reached");
        require(msg.value == tokenPrice.mul(amountToMint), "That is not the right price!");
        
        for(uint256 i = 0; i < amountToMint; i++){
            firstOwner[_tokenIds.current()] = msg.sender;
			_safeMint(msg.sender, _tokenIds.current());
            _tokenIds.increment();
		}
    }
    
    function DevMint(address to, uint256 amountToMint) public onlyOwner {
        for(uint256 i = 0; i < amountToMint; i++){
			_safeMint(to, _tokenIds.current());
            _tokenIds.increment();
		}
    }
    
    function StatusOfSales() public onlyOwner { 
        salesIsOpen = !salesIsOpen;
    }
    
	function BurnNFT(uint256 tokenId) public {
	    require(ownerOf(tokenId) == msg.sender, "You don't own this 0bits");
	    previousOwner[tokenId] = msg.sender;
	    _transfer(msg.sender, 0x000000000000000000000000000000000000dEaD, tokenId);
	}
    
    function WithdrawFunds() public onlyOwner {
		payable(msg.sender).transfer(address(this).balance);
	}
	
	function GetFirstOwner(uint256 tokenId) public view returns(address) {
	    return firstOwner[tokenId];
	}
	
	function GetPreviousOwner(uint256 tokenId) public view returns(address) {
	    return previousOwner[tokenId];
	}
	
	function SetBaseUri(string memory newUri) public onlyOwner {
        require(metadataLocked == false, "Metadata are locked");
        baseUri = newUri;
    }
    
    function LockMetadata() public onlyOwner {
        require(metadataLocked == false, "Metadata are already locked");
        metadataLocked = true;
    }

    function _baseURI() internal override view returns (string memory) {
        return baseUri;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}