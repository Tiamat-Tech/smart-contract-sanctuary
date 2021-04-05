pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// TODO: it should be removed
import "hardhat/console.sol";


contract NFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bool isIssued = false;
    address private _saleAgent = address(0);
    uint256 public totalCap;
    uint256 public endTime;

    constructor(string memory _name, string memory _symbol, uint256 _totalCap, uint256 _endTime)
        ERC721(_name, _symbol) {
        totalCap = _totalCap;
        endTime = _endTime;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwnerOrSaleAgent() {
        require(msg.sender == _saleAgent || msg.sender == owner(), "Ownable: caller is not the owner or the sale agent");
        _;
    }

    function wasIssued() public view returns (bool){
        return isIssued;
    }

    function issueTokens(address holder, uint256 cap) public onlyOwnerOrSaleAgent
    {   
        require(isIssued == false, "NFT: You can't issue more tokens.");
        require(cap <= totalCap, "NFT: You can't issue more then totalCap tokens.");
        uint256 newItemId;

        for(uint i = 0; i < cap; i++){
            _tokenIds.increment();
            newItemId = _tokenIds.current();
            _safeMint(holder, newItemId);

            if (ERC721.totalSupply() == totalCap)
                isIssued = true;
        }
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyOwnerOrSaleAgent {
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURI(string memory baseURI) external onlyOwnerOrSaleAgent {
        _setBaseURI(baseURI);
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "NFT: burn of token that is not own");
        _burn(tokenId);
    }

    function setSaleAgent(address newSaleAgnet) external {
        require(msg.sender == _saleAgent || msg.sender == owner());
        _saleAgent = newSaleAgnet;
    }

    function saleAgent() public view virtual returns (address) {
        return _saleAgent;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        // except minting and burning functions
        if (block.timestamp <= endTime && from != address(0) && to != address(0)) {
            require(from == _saleAgent || from == owner(), "NFT: only owners can transfer tokens during the sale");
        }
    }
}