// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./deps/ERC721.sol";
import "./utils/Counters.sol";
import "./access/Ownable.sol";
import "./deps/extensions/ERC721Enumerable.sol";
import "./deps/extensions/ERC721URIStorage.sol";

contract BoxyCatNFT is ERC721, ERC721Enumerable,ERC721URIStorage, Ownable {
   using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    uint16 public maxSupply = 10069;
    string private _baseTokenURI;
    
    uint256 public _freemintStartDate = 1630008000;
    uint256 public _freemintStopDate = 1630051200;
    uint256 private currentPrice;
    uint256 private currentMintLimit;
    uint256 private maxMintAccount;
    
    uint256 public _mintForAllStartDate = 1630080000;
    

    constructor() ERC721("Boxy Cat NFT", "BXC") {
    }
    
    function setMaxMintPerAccount(uint256 maxMint) public onlyOwner{
        maxMintAccount = maxMint;
    }
    
    function setMaxSupply(uint16 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }
    
    function setCurrentPrice(uint256 price) public onlyOwner {
        currentPrice = price;
    }
    
    function setCurrentMintLimit(uint256 mintLimit) public onlyOwner {
        currentMintLimit = mintLimit;
    }
    
    function setMintForAllStartDate(uint256 startDate) public onlyOwner {
        _mintForAllStartDate = startDate;
    }
    
    function setFreemintStartDate(uint256 startDate) public onlyOwner {
        _freemintStartDate = startDate;
    }
    
    function setFreemintStopDate(uint256 stopDate) public onlyOwner {
        _freemintStopDate = stopDate;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory _newbaseTokenURI) public onlyOwner {
        _baseTokenURI = _newbaseTokenURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    // Get minting limit (for a single transaction) based on current token supply
    function getCurrentMintLimit() public view returns (uint256) {
        return currentMintLimit;
    }

    // Get ether price based on current token supply
    function getCurrentPrice() public view returns (uint256) {
        return currentPrice;
    }
    
    function getCurrentMintLimitPerAccount() public view returns (uint256) {
        return maxMintAccount;
    }

    // Mint new token(s)
    function mint(uint8 _quantityToMint) public payable {
        // at least mint 1 NFT
        require(_quantityToMint >= 1, "Must mint at least 1");
        // can't mint more than current mint limit
        require(
            _quantityToMint <= getCurrentMintLimit(),
            "Maximum current buy limit for individual transaction exceeded"
        );
        // can't mint if the user's NFT has reached the max mint
        require((_quantityToMint + balanceOf(msg.sender)) <= getCurrentMintLimitPerAccount(), "Exceeds max mint per account");
        require(
            (_quantityToMint + totalSupply()) <= maxSupply,
            "Exceeds maximum supply"
        );
        require(
            msg.value == (getCurrentPrice() * _quantityToMint),
            "Ether submitted does not match current price"
        );

        for (uint8 i = 0; i < _quantityToMint; i++) {
            _tokenIds.increment();

            uint256 newItemId = _tokenIds.current();
            _mint(msg.sender, newItemId);
        }
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // Withdraw ether from contract
    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Balance must be positive");
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success == true, "Failed to withdraw ether");
    }
}