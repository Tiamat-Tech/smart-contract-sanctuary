// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/* 
                          .                                                     
   .                 ,   ,   .                          .                 ,   . 
                                                         MMM~                   
                    .MM~                               M    M                   
                   M.   .M                           M.     M                   
                   M     .M                         M.  .+..M                   
                   M       M                        N   ++ M.                   
                   M. ++.   ,                      N.  ++.MM                    
      .,         . MI  ++   M.    .                M   +..M                     
            ,.      M. ~+.   I     ..              . .++ M         ,            
                    .M  ++   M                    .  .+ M.                      
            .   ,    MM  +   .    .               .  +.M=    .   .   .          
                      MM ..      .MM, .    ..OMM  M   MM                        
                       MM.MM8MMN                  NMMMMM                        
                       8 MM    ,.,D            :,.   M..,,7.                    
                     M    MM..,,,  M          M      .,D,,  M                   
                    M    M .,,,.    M.       M      ,,,,M    M                  
                        M.,,,,.    ..M      M     .,,,,  M  ..                  
                       .M,,,.M.   .. MM~++:NM    .:.N.   = ...            ,  .  
                   8   ,D...MMO  ... M MMMM.M  .,..ZMM   .... M            , ,  
                     ,,,D      ...   M   .  D.,,,,      .8.   =                 
   .                M,, M,   ....   M .MMMM  M.,.     ...M   M.           ,   . 
                     M   M+ ..    ,M          M8     .  M   M                   
                      .M7 MM=   MM             .MM.  +M  ,MI                    
                          ZMMMMMM8. ..  ..     .MMMMMMMD                        
                                ..MMMMMMMMMMMMMN..                              
                                                                                
                                                                                
       ...       .                 ,    

       This is such an awesome piece of work that I have to admire it mysellf, I know we all copy from
       each other. So those of you who steal ideas from here, hust give me a little credit :)            
*/

contract BunnyMembership is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, AccessControl {

    // setup max membership types
    uint MAX_DISCOUNT_TYPES = 5;  

    // Keep track of the minting counters, membership types and proces
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;                                               // this is all 721, so there is a token ID
    //Counters.Counter [5] private _membershipCounters = [0,0,0,0,0];                       // track current tokenIDs

    uint private constant ID_STARTS_AT = 1;                                                 // membersship IDs start 1

    // permission roles for this contract - love me some OpenZepplin 4.x
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");

    // what sale mode are we in
    bool private _premintIsOn = false;                                                            // pre-mein on
    bool private _publicSaleOpen = false;                                                         // public-mint-on
 
    // Membership Coonfiguration
    uint private constant MAX_MEMBERSHIP_TYPES = 5;                                             // never more than 5 membership types
    uint [MAX_MEMBERSHIP_TYPES] private _membershipSupply = [0,0,0,0,0];                        // how many memberships, per type
    uint [MAX_MEMBERSHIP_TYPES] private _reservedSupply = [0,0,0,0,0];                          // howmant are available
    uint [MAX_MEMBERSHIP_TYPES] private _forSaleSupply = [0,0,0,0,0];                           // how many available for sale
    uint [MAX_MEMBERSHIP_TYPES] private _memebershipPrice = [0,0,0,0,0];                        // how much retail price
    string [MAX_MEMBERSHIP_TYPES] public _membershipURI = [ "", "", "", "", "" ];               // membership URI
    bool [MAX_MEMBERSHIP_TYPES] private _membershipsAvailableofSale = [false,false,false,false,false];  // available for sale?
    
    // # Token Supply
    uint [MAX_MEMBERSHIP_TYPES] private _totalMintedCount = [0,0,0,0,0];
    uint [MAX_MEMBERSHIP_TYPES] private _reservedMintedCount = [0,0,0,0,0];
    uint [MAX_MEMBERSHIP_TYPES] private _saleMintedCount =[0,0,0,0,0];

   //whitelist and discounts                                                                   // maximum number of discount types
    mapping(address => uint8) private _premintType;                                             // premint multiplier
    uint256 [MAX_MEMBERSHIP_TYPES][5] private _discountTable;                                   // discount table, 1 ticket per mint

    // Setup the token URI for all membership types
    //string [MAX_MEMBERSHIP_TYPES] private _baseTokenURI = [ "", "", "", "", "" ];
    string private _baseTokenURI = "https://gateway.pinata.cloud/ipfs/";

    // OpenSea
    //address constant OPENSEA_PROXY_REGISTRY_ADDRESS = 0x0;                                      // TODO: fix this

    /*  @dev - constructor
        Let's construct this baby and set us in the default state that nothing is for sale 
    */

    constructor() ERC721("BunnyMembership", "BMT") {

        // set the permissions
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        // configure membership types 0 and 1
        //configureMembership( 0, 555, 30, 0.0002 ether );
        //configureMembership( 1, 2555, 100, 0.00005 ether );

       // let's turn on prement for testing // TODO remove for live
       setPreSaleOpen();
    }

    // ----------------------------------------------------------------------------------------------
    // These are all configuration funbctions
    // setup memberships and allow for future expansion

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyRole(MINTER_ROLE) {
        _baseTokenURI = baseURI;
    }

    function configureMembership( uint _mType, uint _mSupply, uint _mReserved, uint _mPrice ) public onlyRole(DEFAULT_ADMIN_ROLE) {

        // make sure membership isn't configured 
        //   for security you only get one shot at this, once configured, can never be reconfigiured

        require( _mType < MAX_MEMBERSHIP_TYPES,     "Invalid membership type" );
        require( _membershipSupply[_mType] != 0,    "Membership already configured" );

        _membershipSupply[_mType] = _mSupply;               // set the total supply of memberships
        _reservedSupply[_mType] = _mReserved;               // set how many to reserve
        _forSaleSupply[_mType] = _mSupply - _mReserved;     // how many are for sale
        _memebershipPrice[_mType] = _mPrice * 0.0001 ether; // set the retail price of memberships TODO reality

        // setup discount rate table
        //_discountTable[_mType][0] = _mPrice;                // Full price
        //_discountTable[_mType][1] = (_mPrice/4) * 3;        // 25% off
        //_discountTable[_mType][2] = _mPrice/2;              // 50% off
       // _discountTable[_mType][3] = _mPrice/4;              // 75% off
        //_discountTable[_mType][4] = 0;                      // FREE
    }

    // ----------------------------------------------------------------------------------------------
    // These functions are about whitelist managment and discounts 

    /*  @dev - addToWhitelist
        Adda single address to the whitelist and also add a discount type for this user
        Whitelists are important post mint as they still control discounts
    */
    function addToWhitelist(address user, uint8 pType) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(WHITELIST_ROLE, user);

        // only store if it's a non-zero value (save storage)
        if (pType != 0) {
           _premintType[user] = pType;
        }
    }
    
    /*  @dev - addToWhitelistArray
        AAllows a group off addresses to be added to the whitelist, but there is a downside
          using this function assumes addresses are all pType = 0
    */
  
    function addToWhitelistArray(address[] memory users) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < users.length; i++) {
            _grantRole(WHITELIST_ROLE, users[i]);
        }
    }

    // ----------------------------------------------------------------------------------------------
    // Control minting flow - start and stop - gosh I hope we neve have to pause

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }
                                                                                                                                                       
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ----------------------------------------------------------------------------------------------
    // Price management and how much supply is available, and what is contract state

    function getPrice( uint _membershipType ) public view returns (uint256) {

        // return premint discount price
        return _memebershipPrice[_membershipType];
    }

    function getTotalSupply( uint _membershipType ) public view returns (uint256) {

        // return premint discount price
        return _membershipSupply[_membershipType];
    }

    function getAvailableSupply( uint _membershipType ) public view returns (uint256) {

        // return premint discount price
        return _forSaleSupply[_membershipType];
    }

    function getPriceForWallet( uint _membershipType, address _user) public view returns (uint256) {

        // return premint discount price
        return _discountTable[_membershipType][_premintType[_user]];
    }

    function isOnWhitelist( address _user ) public view returns (bool) {

        // return whitelist status 
        return hasRole(WHITELIST_ROLE, _user);
    }
   // ----------------------------------------------------------------------------------------------
    // Sale managment

    function isPresaleOpen() public view returns (bool) {

        // is the presale open
        return _premintIsOn;
    }

    function isPublicSaleOpen() public view returns (bool) {

        // is the presale open
        return _publicSaleOpen;
    }

    function setPreSaleOpen() public onlyRole(MINTER_ROLE) {
        _premintIsOn = true;
        _publicSaleOpen = false;
    }

    function setPublicSaleOpen() public onlyRole(MINTER_ROLE) {
        _premintIsOn = false;
        _publicSaleOpen = true;
    }
    
    // ----------------------------------------------------------------------------------------------
    // Mint Mangment and making sure it all works right

    function _requireNotSoldOut() private view {
        //require(

            // TODO: this is not finished
            //_saleMintedCount <= FOR_SALE_SUPPLY,
            //"SOLD OUT"
        //);
    }

    function _requireValidQuantity( uint _membershipType, uint quantity) private view {
        require(
            quantity > 0,
            "quantity must be greater than 0"
            );
            require(
            quantity <= _forSaleSupply[_membershipType],
            "quantity must be less than FOR_SALE_SUPPLY"
        );
    }

    function _requireEnoughSupplyRemaining( uint _membershipType, uint _mintQuantity ) private view {
        //require(
        //    _saleMintedCount + _mintQuantity <= _forSaleSupply[_membershipType],
        //    string(abi.encode("Not enough supply remaining to mint quantity of ", _mintQuantity))
        //);
    }

    function _requireEnoughEth(address user, uint count) private view {
        //equire(
         //   msg.value >= getPrice(user) * count, 
         //   "Value below price of transaction" 
        //);
    }

    function safeMint(address to, string memory uri) public onlyRole(MINTER_ROLE) {

        // check the requirments
        // require( to != address(0), "Invalid Address" );
        // require(_maxSupply >= totalSupply() + _count, "All Tokens Have Been Minted");

        _requireEnoughEth(to, 1);

        // ok let's mint the token
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function totalToken() 
        public
        view
        returns (uint256)
    {
        return _tokenIdCounter.current();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}