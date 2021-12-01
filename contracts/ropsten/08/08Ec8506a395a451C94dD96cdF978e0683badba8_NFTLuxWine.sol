// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @title Contract for ERC 721 Marketplace  
/// @author Andrea Casero - winterandrea
/// @notice Physically (Not yet redeemable) marketplace for luxury wines
/// @dev Minting is made manually one by one and needs to be associated to a custom uri
contract NFTLuxWine is Ownable, ReentrancyGuard, ERC721Enumerable{
    using Counters for Counters.Counter;
    /// @dev Tracks Wine ids. Incremented before minting a new wine. First NFT Luxury Wine starts with _wineIds = 1;
    Counters.Counter private _wineIds;
    
    /// @dev Defined in the constructor function. 
    address payable  _owner;

    /// @dev Remember to add the uri when deploy the contract. 
    string baseURI;
    
    mapping (uint256 => WineMeta) private _wineMeta;
    
    struct WineMeta {
        uint256 id;
        uint256 price;
        bool onSale;
        string name;
        string uri;
    }

    /// @notice Emitted when a new NFT Luxury Wine is minted
    /// @param wineId Wine ID
    /// @param price Wine price (wei)
    /// @dev UI input takes ether but store in the contract as wei 
    /// @param onSale Wine status (boolean)  true = on sale and false = not on sale
    /// @param name Wine name
    event WineMetadata(uint256 indexed wineId, uint256 indexed price, bool indexed onSale, string name, string uri );

    constructor(string memory uri) ERC721("NFTWINE", "WINE") {
        _owner = payable(msg.sender);
         baseURI = uri;
    }

    function _baseURI() internal view override virtual returns (string memory) {
        return baseURI;
    }

    /// @notice Set a new Base URI
    /// @param _newBaseURI new base uri 
    function setBaseURI(string memory _newBaseURI) public virtual onlyOwner {
        baseURI = _newBaseURI;
    }

    /// @notice NFT Luxury Wine full URI associated to the NFT Luxury Wine image
    /// @param wineId Wine Id associated to the nft
    /// @dev We override the parent function adding ".png" at the end of baseURI
     function tokenURI(uint256 wineId)
        public
        view
        override
        returns (string memory)
    {
        return string(abi.encodePacked(super.tokenURI(wineId),".png"));
    }
    
    /// @notice Get all NFT Luxury Wine on sale
    /// @return Array with all the Wine where on sale is true
    /// @dev Needs to be done a further control in the UI to remove completely the wine not on sale -> if(wine.onSale === false) {return}
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
    
     
    /// @notice Set NFT Luxury Wine onSale status and price 
    /// @param _wineId Wine ID
    /// @param _onSale Wine status (boolean)  true = on sale and false = not on sale
    /// @param _price Wine price (wei)
    /// @dev UI input takes ether but store as wei in the contract
    function setWineOnSaleAndPrice(uint256 _wineId, bool _onSale, uint256 _price) public {
        require(_exists(_wineId), "ERC721Metadata: Sale set of nonexistent wine");
        require(_price > 0);
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].onSale = _onSale;
        setWinePrice(_wineId, _price);
    }
    
    /// @notice Set NFT Luxury Wine price
    /// @param _wineId Wine ID
    /// @param _price Wine price (wei)
    /// @dev UI input takes ether but store as wei in the contract
    function setWinePrice(uint256 _wineId, uint256 _price) public {
        require(_exists(_wineId), "ERC721Metadata: Price set of nonexistent wine");
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].price = _price;
    }

    /// @notice Set NFT Luxury Wine onSale status 
    /// @param _wineId Wine ID
    /// @param _onSale Wine status (boolean)  true = on sale and false = not on sale
    function setWineonSale(uint256 _wineId, bool _onSale) public {
        require(_exists(_wineId), "ERC721Metadata: Onsale set of nonexistent wine");
        require(ownerOf(_wineId) == _msgSender());

        _wineMeta[_wineId].onSale = _onSale;
    }

    /// @notice Private function called in the mintWine() function  
    /// @param _wineId Wine ID
    /// @param _meta Wine struct which include the id, price, onSale, name and uri
    function _setWineMeta(uint256 _wineId, WineMeta memory _meta) private {
        require(_exists(_wineId));
        require(ownerOf(_wineId) == _msgSender());
        _wineMeta[_wineId] = _meta;
    }
    
    /// @notice Checks if wine is on sale
    /// @param _wineId Wine ID
    /// @return true or false
    function isWineOnSale(uint256 _wineId) public view returns(bool){
        require(_exists(_wineId), "ERC721Metadata: Sale query of nonexistent wine");
        return _wineMeta[_wineId].onSale;
    }
    
    /// @notice Checks wine price
    /// @param _wineId Wine ID
    /// @return price in wei
    /// @dev converted in the UI with Ether
    function winePrice(uint256 _wineId) public view returns(uint256){
        require(_exists(_wineId), "ERC721Metadata: Price query of nonexistent wine");
        return _wineMeta[_wineId].price;
    }
    
    /// @notice Checks wine metadata
    /// @param _wineId Wine ID
    /// @return struct with all the meta data associated to the wine ID
    function wineMeta(uint256 _wineId) public view returns (WineMeta memory) {
        require(_exists(_wineId));
        return _wineMeta[_wineId];
    }
    
   
    /// @notice Purchase a NFT Luxury wine
    /// @param _wineId wine ID selected from the UI
    /// @dev require exact payment to avoid having to send ETH back to sender. Once bought set the onsale status on false
     function purchaseWine(uint256 _wineId) public payable nonReentrant {
        require(msg.sender != address(0) && msg.sender != ownerOf(_wineId));
        require(msg.value == _wineMeta[_wineId].price, "Please submit the asking price in order to complete the purchase" );
        require(_wineMeta[_wineId].onSale == true, "The wine is not on sale" );
        address wineSeller = ownerOf(_wineId);
        _wineMeta[_wineId].onSale = false;
        _transfer(wineSeller, msg.sender, _wineId);
        payable(wineSeller).transfer(msg.value);
    }
    
    
    /// @notice Mint a new NFT Luxury Wine
    /// @param _uri Wine uri associated with its image
    /// @dev In the UI we render the image adding ".png" to the uri
    /// @param _name Wine name
    /// @param _price Wine price (wei)
    /// @dev UI input takes ether but store in the contract as wei 
    /// @param _onSale Wine status (boolean)  true = on sale and false = not on sale
    /// @return NFT Luxury Wine Id
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
    
    /// @notice Get NFT Luxury Wine contract address
    /// @return contract address
    function getThisAddress() public view returns(address){
        return address(this);
    }
    
    /// @notice Get NFT Luxury Wine contract owner address
    /// @return contract owner address
    function getOwnerAddress() public view returns(address){
        return _owner;
    }
    
}