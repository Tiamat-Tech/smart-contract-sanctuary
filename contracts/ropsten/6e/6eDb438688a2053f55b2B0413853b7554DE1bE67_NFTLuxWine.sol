// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFTLuxWine is  Ownable, ReentrancyGuard, ERC721URIStorage{
    using Counters for Counters.Counter;
    Counters.Counter private _wineIds;
    
    address payable  _owner;
    
    mapping (uint256 => WineMeta) private _wineMeta;
    
    struct WineMeta {
        uint256 id;
        uint256 price;
        string name;
        string uri;
        bool onSale;
    }


    constructor() ERC721("NFTWINE", "WINE") {
        _owner = payable(msg.sender);
    }
    
    function _baseURI() internal pure override returns (string memory) {
        return "https://gateway.pinata.cloud/ipfs/QmQz4eLSthK6CPgk8zCHuNNmQkVbQPL9JLKyk6di6TKFgk/";
    }
    
    
    
    
    //SET FUNCTION
    
    function setWineOnSale(uint256 _wineId, bool _sale, uint256 _price) public {
        require(_exists(_wineId), "ERC721Metadata: Sale set of nonexistent wine");
        require(_price > 0);
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].onSale = _sale;
        setWinePrice(_wineId, _price);
    }
    
    function setWinePrice(uint256 _wineId, uint256 _price) public {
        require(_exists(_wineId), "ERC721Metadata: Price set of nonexistent wine");
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].price = _price;
    }
    
    function setWineMeta(uint256 _wineId, WineMeta memory _meta) private {
        require(_exists(_wineId));
        require(ownerOf(_wineId) == _msgSender());
        _wineMeta[_wineId] = _meta;
    }
    
    //VIEW FUNCTION
    function isWineOnSale(uint256 _wineId) public view returns(bool){
        require(_exists(_wineId), "ERC721Metadata: Sale query of nonexistent wine");
        return _wineMeta[_wineId].onSale;
    }
    
    function winePrice(uint256 _wineId) public view returns(uint256){
        require(_exists(_wineId), "ERC721Metadata: Price query of nonexistent wine");
        return _wineMeta[_wineId].price;
    }
    
    
    function wineMeta(uint256 _wineId) public view returns (WineMeta memory) {
        require(_exists(_wineId));
        return _wineMeta[_wineId];
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return string(abi.encodePacked(super.tokenURI(tokenId),".png"));
    }
    
    // PURCHASE FUNCTION
     function purchaseWine(uint256 _wineId) public payable nonReentrant {
        require(msg.sender != address(0) && msg.sender != ownerOf(_wineId));
        //require(msg.value >= _wineMeta[_wineId].price)
        require(msg.value == _wineMeta[_wineId].price, "Please submit the asking price in order to complete the purchase" );
        require(_wineMeta[_wineId].onSale == true, "The wine is not on sale" );
        address wineSeller = ownerOf(_wineId);
        _wineMeta[_wineId].onSale = false;
        _transfer(wineSeller, msg.sender, _wineId);
        payable(wineSeller).transfer(msg.value);
        
        
        //_approve(msg.sender, _wineId);
        //_wineMeta[_wineId].onSale = false;
        //safeTransferFrom(wineSeller,  msg.sender, _wineId);
        //payable(wineSeller).transfer(msg.value);
    }
    //1 Ether = 1000000000000000000 Wei
    
    
    // MINT FUNCTION
    function mintWine() public onlyOwner returns (uint256) {
         _wineIds.increment();

        uint256 newWineId = _wineIds.current();
        _mint(_owner, newWineId);
        return newWineId; 
    }
    
    function getThisAddres() public view returns(address){
        return address(this);
    }
    
    function getOwnerAddres() public view returns(address){
        return _owner;
    }
    
}