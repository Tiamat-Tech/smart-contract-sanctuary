//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract RC3 is ERC721PresetMinterPauserAutoId {
    using Counters for Counters.Counter;

    uint private id;
    Counters.Counter private _tokenIdTracker;

    enum Category { Music, Painting }
    enum TokenState { Pending, ForSale, Sold, Transferred }

    struct Card {
        uint price;
        Category category;
        TokenState state;
    }   

    event Minted(uint id, uint price);
    event Bought(address indexed buyer, uint tokenId, uint value);
    event PriceUpdated(uint id, uint price);

    mapping(uint => Card) private _cards;

    constructor() ERC721PresetMinterPauserAutoId("RareCandy3D", "RC3", "https://rarecandy.xyz/api/token/") {
    }

    function mint(address to, uint _price, bool _isMusic, bool _isEnabled) external {

        _cards[_tokenIdTracker.current()].price = _price;
        
        if(_isMusic) _cards[_tokenIdTracker.current()].category = Category.Music;
        else _cards[_tokenIdTracker.current()].category = Category.Painting;

        if(_isEnabled) _cards[_tokenIdTracker.current()].state = TokenState.ForSale;
        else _cards[_tokenIdTracker.current()].state = TokenState.Pending;
        
        super.mint(to);
        
        emit Minted(_tokenIdTracker.current(), _price);
        _tokenIdTracker.increment();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(TokenState.ForSale == _cards[tokenId].state, "No Sale");
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function buyRC3(uint256 _tokenId) external payable virtual returns(bool) {

        require(msg.value >= _cards[_tokenId].price, "Price issue");
        
        address owner = ownerOf(_tokenId);
        payable(owner).transfer(msg.value);
        transferFrom(owner, msg.sender, _tokenId);
        _cards[_tokenId].state = TokenState.Sold;
        
        emit Bought(msg.sender, _tokenId, msg.value);
        return true;
    }

    function setTokenPrice(uint256[] calldata _ids, uint256 _setPrice) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        for (uint i = 0; i < _ids.length; i++) {
            _cards[_ids[i]].price = _setPrice;
            emit PriceUpdated(_ids[i], _setPrice);
        }
    } 

    function basfeURI() external view virtual returns (string memory) {
        return _baseURI();
    }

    function getCategory(uint _tokenId) external view returns (Category) {
        return _cards[_tokenId].category;
    }

    function getState(uint _tokenId) external view returns (TokenState) {
        return _cards[_tokenId].state;
    }

    function getPrice(uint _tokenId) external view returns (uint price) {
        return _cards[_tokenId].price;
    }
}