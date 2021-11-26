// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTLuxWine is  Ownable, ReentrancyGuard, ERC721{
    using Counters for Counters.Counter;
    Counters.Counter private _wineIds;
    
    address payable  _owner;

    string baseURI = "https://gateway.pinata.cloud/ipfs/QmZUn1TJScL9m51fyqm1Pnx6HtCNTci2v3FvukuSSfshYM/";
    
    mapping (uint256 => WineMeta) private _wineMeta;
    
    struct WineMeta {
        uint256 id;
        uint256 price;
        bool onSale;
        string name;
        string uri;
    }

    event WineMetadata(uint256 indexed wineId, uint256 indexed price, bool indexed onSale, string name, string uri );

    constructor() ERC721("NFTWINE", "WINE") {
        _owner = payable(msg.sender);
    }

    function _baseURI() internal view override virtual returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public virtual onlyOwner {
        baseURI = _newBaseURI;
    }

     function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return string(abi.encodePacked(super.tokenURI(tokenId),".png"));
    }
    
    
    // GET ALL WINE ON SALE
       function getWineAllOnSale () public view virtual returns( WineMeta[] memory ) {
        WineMeta[] memory winesOnSale = new WineMeta[](_wineIds.current());
        uint256 counter = 0;

        for(uint i = 1; i < _wineIds.current() + 1; i++) {
            if(_wineMeta[i].onSale == true) {
                winesOnSale[counter] = _wineMeta[i];
                counter++;
            }
        }
        return winesOnSale;
    }
    
    
    //SET FUNCTION
    
    function setWineOnSaleAndPrice(uint256 _wineId, bool _onSale, uint256 _price) public {
        require(_exists(_wineId), "ERC721Metadata: Sale set of nonexistent wine");
        require(_price > 0);
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].onSale = _onSale;
        setWinePrice(_wineId, _price);
    }
    
    function setWinePrice(uint256 _wineId, uint256 _price) public {
        require(_exists(_wineId), "ERC721Metadata: Price set of nonexistent wine");
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].price = _price;
    }

    function setWineonSale(uint256 _wineId, bool _onSale) public {
        require(_exists(_wineId), "ERC721Metadata: Onsale set of nonexistent wine");
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].onSale = _onSale;
    }

    function setWineName(uint256 _wineId, string memory _name) public {
        require(_exists(_wineId), "ERC721Metadata: Price set of nonexistent wine");
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].name = _name;
    }

    function setWineUri(uint256 _wineId, string memory _uri) public {
        require(_exists(_wineId), "ERC721Metadata: Price set of nonexistent wine");
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].uri = _uri;
    }
    
    function _setWineMeta(uint256 _wineId, WineMeta memory _meta) private {
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
    
   
    
    // PURCHASE FUNCTION
     function purchaseWine(uint256 _wineId) public payable nonReentrant {
        require(msg.sender != address(0) && msg.sender != ownerOf(_wineId));
        //require(msg.value >= _wineMeta[_wineId].price)
        require(msg.value == _wineMeta[_wineId].price, "Please submit the asking price in order to complete the purchase" );
        require(_wineMeta[_wineId].onSale == true, "The wine is not on sale" );
        address wineSeller = ownerOf(_wineId);
        _wineMeta[_wineId].onSale = true;
        _transfer(wineSeller, msg.sender, _wineId);
        payable(wineSeller).transfer(msg.value);
        
        
        //_approve(msg.sender, _wineId);
        //_wineMeta[_wineId].onSale = false;
        //safeTransferFrom(wineSeller,  msg.sender, _wineId);
        //payable(wineSeller).transfer(msg.value);
    }
    //1 Ether = 1000000000000000000 Wei
    
    
    // MINT FUNCTION
    function mintWine( string memory _uri, string memory _name, uint256 _price, bool _onSale) public onlyOwner returns (uint256) {
        require(_price > 0);
        _wineIds.increment();

        uint256 newWineId = _wineIds.current();
        _mint(_owner, newWineId);

        WineMeta memory meta = WineMeta(newWineId, _price, _onSale, _name, _uri);
        _setWineMeta(newWineId, meta);
        emit WineMetadata(newWineId, _price, _onSale, _name, _uri);

        return newWineId; 
    }
    
    function getThisAddres() public view returns(address){
        return address(this);
    }
    
    function getOwnerAddres() public view returns(address){
        return _owner;
    }
    
}