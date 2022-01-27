// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Authorizable is Ownable {

    mapping(address => bool) public authorized;
    address[] public adminList;

    event AddAuthorized(address indexed _address);
    event RemoveAuthorized(address indexed _address, uint index);

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || owner() == msg.sender,"Authorizable: caller is not the SuperAdmin or Admin");
        _;
    }

    function addAuthorized(address _toAdd) onlyOwner() external {
        require(_toAdd != address(0),"Authorizable: _toAdd isn't vaild address");
        authorized[_toAdd] = true;
        adminList.push(_toAdd);
        emit AddAuthorized(_toAdd);
    }

    function removeAuthorized(address _toRemove,uint _index) onlyOwner() external {
        require(_toRemove != address(0),"Authorizable: _toRemove isn't vaild address");
        require(adminList[_index] == _toRemove,"Authorizable: _index isn't valid index");
        authorized[_toRemove] = false;
        delete adminList[_index];
        emit RemoveAuthorized(_toRemove,_index);
    }

    function getAdminList() public view returns(address[] memory ){
        return adminList;
    }

}

contract Card is ERC721, Authorizable {

    using Strings for uint256;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    // card Type
    // 1 => Green
    // 2 => sliver
    // 3 => gold
    // 4 => VIP
    // 5 => Legendary

    uint256[] public counters;

    uint256 public totalSupply;

    mapping(uint256 => uint256) public idCardType;

    string public baseURI_;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping(address => EnumerableSet.UintSet) private _holderTokens;

    constructor(string memory _name,string memory _symbol,string memory _baseTokenURI,uint256[] memory _counters) ERC721(_name, _symbol) {
        require(bytes(_baseTokenURI).length != 0,"PlayingCard: Use valid URI");
        require(_counters.length > 0,"PlayingCard: _counters length must be greater than zero");
        _setBaseURI(_baseTokenURI);
        counters = _counters;
    }

    function addNewCardCounter(uint _counter) external onlyOwner(){
        require(counters[counters.length] < _counter,"PlayingCard: not a valid counter");
        counters.push(_counter);
    }
    
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256){
        return _holderTokens[_owner].at(_index);
    }
    
    function _setBaseURI(string memory _baseTokenURI) internal {
        baseURI_ = _baseTokenURI;
    }

    function _mintCard(address _to,uint256 _cardType) internal {
        uint tokenId = counters[_cardType.sub(1)];
        totalSupply = totalSupply.add(1);
        _holderTokens[_to].add(tokenId);
        idCardType[tokenId] = _cardType;
        _safeMint(_to,tokenId);
        counters[_cardType.sub(1)]++;
    }

    function _batchMintCard(address _to,uint256 _cardType,uint256 _numberOfToken) internal{
        require(_numberOfToken > 0,"NFT4Play: use valid token amount");
        for (uint256 i = 0; i < _numberOfToken; i++) {
            _mintCard(_to,_cardType);
        }
    }

    function mintCard(address _to,uint256 _cardType) external onlyAuthorized() {
        require(_to != address(0),"PlayingCard: _to address not a valid");
        require(_cardType > 0 && _cardType <= totalCardType(),"PlayingCard: _not a valid card Type");
        _mintCard(_to,_cardType);
    }

    function batchMintCard(address _to,uint256 _cardType,uint256 _numberOfToken) external onlyAuthorized(){ 
        require(_to != address(0),"PlayingCard: _to address not a valid");
        require(_cardType > 0 && _cardType <= totalCardType(),"PlayingCard: _not a valid card Type");
        _batchMintCard(_to,_cardType,_numberOfToken);
    }
    
    function batchMintCards(address[] memory _addresses,uint256 _cardType,uint256[] memory _numberOfTokens) external onlyAuthorized() {
        require(_addresses.length > 0 ,"NFT4Play: use valid _addresses list");
        require(_addresses.length == _numberOfTokens.length,"NFT4Play: _addresses length not equal to _numberOfTokens lenght");
        require(_cardType > 0 && _cardType <= totalCardType(),"PlayingCard: _not a valid card Type");
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0),"PlayingCard: _to address not a valid");
            _batchMintCard(_addresses[i],_cardType,_numberOfTokens[i]);
        }
    }
    
    function burn(address _address,uint _tokenId) external {
        require(_address == _msgSender() || _isApprovedOrOwner(_msgSender(), _tokenId), "NFT4Play: burn caller is not owner nor approved");
        _holderTokens[_address].remove(_tokenId);
        totalSupply = totalSupply.sub(1);
        _burn(_tokenId);
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseURI_;
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "NFT4Play: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI,tokenId.toString(),".json")) : "";
    }
    
    function transferFrom(address from,address to,uint256 tokenId) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NFT4Play: transfer caller is not owner nor approved");
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from,address to,uint256 tokenId) public override {
        safeTransferFrom(from, to, tokenId, "");
    }
    
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes memory _data) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "NFT4Play: transfer caller is not owner nor approved");
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _safeTransfer(from, to, tokenId, _data);
    }
    
    function getTokens(address _address) external view returns(uint256[] memory){
        return _holderTokens[_address].values();
    }

    function totalCardType() public view returns(uint){
        return counters.length;
    }
     
}