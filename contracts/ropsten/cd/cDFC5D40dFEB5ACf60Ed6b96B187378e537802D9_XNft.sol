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

    uint256 public lastTokenCategoryId;
    mapping(uint256 => TokenCategory) public tokenCategories;

    mapping(address => string) public names;
    address[] public userArray;
    mapping(address => bool) public userMapping;

    mapping(uint256 => bool) public tokenSold;
    uint256[] public tokenSoldArr;
    uint256 public soldTokensLength;

    mapping(uint256 => uint256) public tokenPrices;
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

    function updatePrice(uint256 tokenCategoryId, uint256 _new_price) external onlyOwner {
        tokenPrices[tokenCategoryId] = _new_price;
    }

    function updateTreasurer(address payable _new_treasurer) external onlyOwner {
        treasurer = _new_treasurer;
    }

    function buyMultiple(uint256 tokenCategoryId, uint256[] memory _tokenIds, string[] memory _tokenURIs) external payable {
        require(!isPaused, "XNft contract is paused.");
        TokenCategory memory tokenCategory = tokenCategories[tokenCategoryId];
        require(tokenCategory.isValue , "XNft: Token category not found.");
        require(msg.value == tokenPrices[tokenCategoryId].mul(_tokenIds.length), 'XNft: Wrong value to buy Token.');
        for(uint256 i = 0; i < _tokenIds.length; i++){
            buy(tokenCategoryId, _tokenIds[i], _tokenURIs[i]);
        }
        treasurer.transfer(msg.value);
        totalSale = totalSale.add(msg.value);
        if(!userMapping[msg.sender]){
            userArray.push(msg.sender);
        }
    }

    function buy(uint256 tokenCategoryId, uint256 _tokenId, string memory _tokenURI) internal {
        require(!tokenSold[_tokenId], 'XNft: Token already sold.');

        tokenSold[_tokenId] = true;
        soldTokensLength = soldTokensLength.add(1);
        tokenSoldArr.push(_tokenId);
        _mint(msg.sender, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);

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

    function getLatestNames(uint256 length) view external returns(string memory){
        string memory namesCommaSeperated = "";
        uint256 from = soldTokensLength.sub(1);
        uint256 to;
        if(length < from){
            to = soldTokensLength.sub(length);
        }
        for(uint256 i = from; i >=  to; i--){
            string memory name = "";
            if(keccak256(abi.encodePacked(names[this.ownerOf(tokenSoldArr[i])])) == keccak256(abi.encodePacked(""))){
                name = addressToString(this.ownerOf(tokenSoldArr[i]));
            }else{
                name = names[this.ownerOf(tokenSoldArr[i])];
            }
            namesCommaSeperated = string(abi.encodePacked(namesCommaSeperated, name, ','));
        }
        return namesCommaSeperated;
    }

    function addressToString(address account) internal pure returns(string memory) {
        bytes memory data = abi.encodePacked(account);
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

}