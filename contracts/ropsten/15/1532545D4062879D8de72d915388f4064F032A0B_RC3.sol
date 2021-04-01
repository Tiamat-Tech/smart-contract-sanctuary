//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract RC3 is ERC721PresetMinterPauserAutoId {

    uint private id = 1;
    address payable public maker; 

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

    constructor() ERC721PresetMinterPauserAutoId("RareCandy3D", "RC3", "https://rarecandy.xyz/api/token/") {}

    function mint(address to, uint _price, bool _isMusic, bool _isEnabled) external {
        super.mint(to);

        _cards[id].price = _price;
        
        if(_isMusic) _cards[id].category = Category.Music;
        else _cards[id].category = Category.Painting;

        if(_isEnabled) _cards[id].state = TokenState.ForSale;
        else _cards[id].state = TokenState.Pending;
        
        emit Minted(id, _price);
        id++;
    }
    
    function buyRC3(uint256 _tokenId) external payable returns(bool) {

        require(msg.value >= _cards[_tokenId].price, "Price issue");
        require(TokenState.ForSale == _cards[_tokenId].state, "No Sale");
        
        maker.transfer(msg.value);
        transferFrom(maker, msg.sender, _tokenId);
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