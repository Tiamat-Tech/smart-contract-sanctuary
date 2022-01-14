// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface BaseToken {
    function mint(address account, uint256 amount) external;
}

/// @custom:security-contact [email protected]
contract NguNFT is ERC721, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    address admin;

    mapping (uint => uint) public lastBlockClaim;
    mapping (uint => uint) public yieldPerBlock;
    mapping (uint => bool) public forSale;
    mapping (uint => uint) public salePrice;

    struct NFT {
        address owner;
        bool currentlyForSale;
        uint price;
        uint timesSold;
    }

     mapping (uint => NFT) public NFTs;

     mapping (address => uint[]) public NFTOwners;

    BaseToken public _baseToken;

    Counters.Counter public _tokenIdCounter;

    constructor(address _token) ERC721("NGU PERPETUAL YIELD NFT", "nguNFT") {
        _baseToken = BaseToken(_token);
        admin = msg.sender;
        
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ngudao.com/id/";
    }

    function setBaseToken(address _token) public onlyOwner{
        _baseToken = BaseToken(_token);
    }

    function safeMint(address _to, uint _yieldPerBlock, uint _salePrice, bool _forSale) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
        lastBlockClaim[tokenId] = block.number;
        yieldPerBlock[tokenId] = _yieldPerBlock;
        forSale[tokenId] = _forSale;
        salePrice[tokenId] = _salePrice;

        NFTs[tokenId].owner = _to;
        NFTs[tokenId].currentlyForSale = _forSale;
        NFTs[tokenId].price = _salePrice;
        NFTs[tokenId].timesSold = 1;
        NFTOwners[_to].push(tokenId);
    }

    function setForSale(uint tokenId, bool _forSale, uint _salePrice) external {
        require(ownerOf(tokenId) == msg.sender);
        forSale[tokenId] = _forSale;
        salePrice[tokenId] = _salePrice;
    }

    function setSalePrice(uint tokenId, uint _salePrice) external {
        require(ownerOf(tokenId) == msg.sender);
        salePrice[tokenId] = _salePrice;
    }

    function buyNFT(uint tokenId) external payable {
        require(NFTs[tokenId].currentlyForSale,'NOT FOR SALE');
        require(msg.value >= NFTs[tokenId].price, 'Insufficient Funds');
        payable(ownerOf(tokenId)).transfer(msg.value);
        _claimYield(tokenId);
        forSale[tokenId] = false;
        NFTs[tokenId].currentlyForSale = false;
        NFTs[tokenId].timesSold++;
        NFTs[tokenId].owner = msg.sender;
        _transfer(ownerOf(tokenId), msg.sender, tokenId);
    }

     function sellNFT (uint NFTNumber, uint price) external {
        require(msg.sender == NFTs[NFTNumber].owner, 'NOT OWNER');
        require(price > 0, 'price is zero');
        NFTs[NFTNumber].price = price;
        NFTs[NFTNumber].currentlyForSale = true;
    }

    function dontSellNFT (uint NFTNumber) external {
        require(msg.sender == NFTs[NFTNumber].owner);
        NFTs[NFTNumber].currentlyForSale = false;
    }
    
    function giftNFT (uint NFTNumber, address receiver) external {
        require(msg.sender == NFTs[NFTNumber].owner);
        NFTs[NFTNumber].owner = receiver;
        NFTOwners[receiver].push(NFTNumber);
        _transfer(msg.sender, receiver, NFTNumber);
    }

     function NFTOwningHistory (address _address) external view returns (uint[] memory) {
        return NFTOwners[_address];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
       
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _claimYield(tokenId);
        _transfer(from, to, tokenId);
    }

    
    function getNFTInfo (uint NFTNumber) public view returns (address, bool, uint, uint) {
        return (NFTs[NFTNumber].owner, NFTs[NFTNumber].currentlyForSale, NFTs[NFTNumber].price, NFTs[NFTNumber].timesSold);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        _claimYield(tokenId);
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _claimYield(tokenId);
        _safeTransfer(from, to, tokenId, _data);
    }


    function _claimYield(uint tokenId) internal {
        require(lastBlockClaim[tokenId] < block.number, 'Block Number');
        uint distance = SafeMath.sub(block.number, lastBlockClaim[tokenId]);
        uint yieldAmount = SafeMath.mul(distance, yieldPerBlock[tokenId]);
        lastBlockClaim[tokenId] = block.number;
        uint adminFee = SafeMath.div(SafeMath.mul(yieldAmount,100),1000);
        _baseToken.mint(admin, adminFee);
        _baseToken.mint(NFTs[tokenId].owner, yieldAmount);
    }

    function claimYield(uint tokenId) external {
        require(lastBlockClaim[tokenId] < block.number, 'Block Number');
        _claimYield(tokenId);
    }
}