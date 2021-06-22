// contracts/XNft.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract XNft is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    struct TokenCategory {
        string title;
        uint256 startId;
        uint256 endId;
        string imageURI;
        bool isValue;
    }

    uint256 public lastTokenId;
    uint256 public lastTokenCategoryId;
    mapping(uint256 => bool) public tokenSold;
    uint256[] public tokenSoldArr;
    mapping(address => string) public names;
    address[] public userArray;
    mapping(address => bool) public userMapping;
    mapping(uint256 => TokenCategory) public tokenCategories;
    mapping(uint256 => uint256) public tokenPrices;
    mapping(uint256 => uint256) public lastMintedTokenIds;
    uint256 public soldTokensLength;
    address payable public treasurer;
    uint256 public totalSale;

    bool public isPaused = true;

    event TokenSold(uint256 indexed categoryId, address indexed to, uint256 indexed tokenId);
    event NameUpdated(address indexed user, string name);
    event TokenCategoryAdded(uint256 indexed categoryId, uint256 startId, uint256 endId, string imageURI, uint256 price);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        treasurer = payable(msg.sender);
    }

    function pause() external onlyOwner {
        isPaused = true;
    }

    function unPause() external onlyOwner {
        isPaused = false;
    }

    function addTokenCategory(string memory title, uint256 tokenLength, string memory imageURI, uint256 price) onlyOwner external {
        TokenCategory memory lastTokenCategory = tokenCategories[lastTokenCategoryId];
        uint256 startId = 1;
        if(lastTokenCategory.isValue){
            startId = (lastTokenCategory.endId).add(1);
        }
        lastTokenCategoryId = lastTokenCategoryId.add(1);
        TokenCategory memory tokenCategory = TokenCategory( title, startId, startId.add((tokenLength.sub(1))), imageURI, true);
        tokenCategories[lastTokenCategoryId] = tokenCategory;
        tokenPrices[lastTokenCategoryId] = price;
        emit TokenCategoryAdded(lastTokenCategoryId, startId, startId.add((tokenLength.sub(1))), imageURI, price);
    }

    function awardMultipleForSale(uint256 tokenCategoryId, string[] memory _tokenURIs) public onlyOwner {
        TokenCategory memory tokenCategory = tokenCategories[tokenCategoryId];
        uint256 lastMintedTokenId = lastMintedTokenIds[tokenCategoryId];
        require(tokenCategory.isValue , "XNft: Token category not found.");
        if(lastMintedTokenId == 0){
            lastMintedTokenId = tokenCategory.startId.sub(1);
        }
        for(uint256 i = 0; i < _tokenURIs.length; i++){
            require(lastMintedTokenIds[tokenCategoryId] < tokenCategory.endId, "XNft: No further token can be minted for following category.");
            uint256 newTokenId = lastMintedTokenId.add(1);
            lastMintedTokenIds[tokenCategoryId] = newTokenId;
            _mint(address(this), newTokenId);
            _setTokenURI(newTokenId, _tokenURIs[i]);
            lastMintedTokenId = newTokenId;
        }
    }

    function updatePrice(uint256 tokenCategoryId, uint256 _new_price) external onlyOwner {
        tokenPrices[tokenCategoryId] = _new_price;
    }

    function updateTreasurer(address payable _new_treasurer) external onlyOwner {
        treasurer = _new_treasurer;
    }

    function buyMultiple(uint256 tokenCategoryId, uint256[] memory _tokenIds) external payable {
        require(!isPaused, "XNft contract is paused.");
        TokenCategory memory tokenCategory = tokenCategories[tokenCategoryId];
        require(tokenCategory.isValue , "XNft: Token category not found.");
        require(msg.value == tokenPrices[tokenCategoryId].mul(_tokenIds.length), 'XNft: Wrong value to buy Token.');
        for(uint256 i = 0; i < _tokenIds.length; i++){
            buy(tokenCategoryId, _tokenIds[i]);
        }
        treasurer.transfer(msg.value);
        totalSale = totalSale.add(msg.value);
        if(!userMapping[msg.sender]){
            userArray.push(msg.sender);
        }
    }

    function buy(uint256 tokenCategoryId, uint256 _tokenId) internal {
        uint256 lastMintedTokenId = lastMintedTokenIds[tokenCategoryId];

        require(_tokenId <= lastMintedTokenId, 'XNft: token not minted yet.');
        require(!tokenSold[_tokenId], 'XNft: Token already sold.');

        tokenSold[_tokenId] = true;
        soldTokensLength = soldTokensLength.add(1);
        tokenSoldArr.push(_tokenId);
        this.transferFrom(address(this), msg.sender, _tokenId);

        emit TokenSold(tokenCategoryId, msg.sender, _tokenId);
    }

    function updateName(string memory new_name) external {
        names[msg.sender] = new_name;
        emit NameUpdated(msg.sender, new_name);
    }

    function getSoldTokensCommaSeperated(uint256 tokenCategoryId) view external returns(string memory){
        TokenCategory memory tokenCategory = tokenCategories[tokenCategoryId];
        string memory soldTokens = "";
        if(tokenCategory.isValue){
            for(uint256 i = tokenCategory.startId; i <= tokenCategory.endId; i++){
                if(tokenSold[i]){
                    soldTokens = string(abi.encodePacked(soldTokens, i.toString(), ','));
                }
            }
        }
        return soldTokens;
    }

}