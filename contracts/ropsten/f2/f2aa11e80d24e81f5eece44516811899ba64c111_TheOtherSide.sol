// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/****************************************
 * @author: tos_nft                 *
 * @team:   TheOtherSide                *
 ****************************************
 *   TOS-ERC721 provides low-gas    *
 *           mints + transfers          *
 ****************************************/

import './Delegated.sol';
import './ERC721EnumerableT.sol';
import "@openzeppelin/contracts/utils/Strings.sol";

interface IERC20Proxy{
  function burnFromAccount( address account, uint leaves ) external payable;
  function mintToAccount( address[] calldata accounts, uint[] calldata leaves ) external payable;
}

interface IERC1155Proxy{
  function burnFrom( address account, uint[] calldata ids, uint[] calldata quantities ) external payable;
}

contract TheOtherSide is ERC721EnumerableT, Delegated {
  using Strings for uint;

  enum MoonType {
      Genesis,
      Normal
  }

  struct Moon {
    address owner;
    MoonType moonType;
  }

  bool public revealed = false;
  string public notRevealedUri = "xxxxxxx";

  uint public MAX_SUPPLY   = 500;
  uint public PRICE        = 0.065 ether;

  Moon[] public moons;

  bool public isWhitelistActive = false;

  mapping(address => uint) public accessList;


  mapping(address => uint) private _balances;
  string private _tokenURIPrefix = 'https://ipfs.tos.io/metadata/';
  string private _tokenURISuffix = '';

  constructor()
    ERC721T("The Other Side of the Moon", "TOS"){
  }

  //external
  fallback() external payable {}


  function balanceOf(address account) public view override returns (uint) {
    require(account != address(0), "TOS: balance query for the zero address");
    return _balances[account];
  }

  function isOwnerOf( address account, uint[] calldata tokenIds ) external view override returns( bool ){
    for(uint i; i < tokenIds.length; ++i ){
      if( moons[ tokenIds[i] ].owner != account )
        return false;
    }

    return true;
  }

  function ownerOf( uint tokenId ) public override view returns( address owner_ ){
    address owner = moons[tokenId].owner;
    require(owner != address(0), "TENSEI: query for nonexistent token");
    return owner;
  }

  function tokenByIndex(uint index) external view override returns (uint) {
    require(index < totalSupply(), "TENSEI: global index out of bounds");
    return index;
  }

  function tokenOfOwnerByIndex(address owner, uint index) public view override returns (uint tokenId) {
    uint count;
    for( uint i; i < moons.length; ++i ){
      if( owner == moons[i].owner ){
        if( count == index )
          return i;
        else
          ++count;
      }
    }

    revert("ERC721Enumerable: owner index out of bounds");
  }

  function tokenURI(uint tokenId) external view override returns (string memory) {
    require(_exists(tokenId), "MOON: URI query for nonexistent token");

    if(revealed == false) {
        return notRevealedUri;
    }
    return string(abi.encodePacked(_tokenURIPrefix, tokenId.toString(), _tokenURISuffix));
  }

  function totalSupply() public view override returns( uint totalSupply_ ){
    return moons.length;
  }

  function walletOfOwner( address account ) external view override returns( uint[] memory ){
    uint quantity = balanceOf( account );
    uint[] memory wallet = new uint[]( quantity );
    for( uint i; i < quantity; ++i ){
        wallet[i] = tokenOfOwnerByIndex( account, i );
    }
    return wallet;
  }

  //only owner
  function reveal() external onlyDelegates {
      revealed = true;
  }

  //payable
  function mint( uint quantity ) external payable {
    //flag to check whitelist address
    if( isWhitelistActive ){
      require( accessList[ msg.sender ] >= quantity, "MOON: Account is not on the access list" );
      accessList[ msg.sender ] -= quantity;
    }

    uint supply = totalSupply();
    require( supply + quantity <= MAX_SUPPLY, "MOON: Mint/order exceeds supply" );
    for(uint i; i < quantity; ++i){
      _mint( msg.sender, supply++, MoonType.Genesis );
    }
  }


  //onlyDelegates
  function mint_(uint[] calldata quantity, address[] calldata recipient, MoonType[] calldata types_ ) external payable onlyDelegates{
    require(quantity.length == recipient.length, "MOON: Must provide equal quantities and recipients" );
    require(recipient.length == types_.length,   "MOON: Must provide equal recipients and types" );

    uint totalQuantity;
    uint supply = totalSupply();
    for(uint i; i < quantity.length; ++i){
      totalQuantity += quantity[i];
    }
    require( supply + totalQuantity < MAX_SUPPLY, "MOON: Mint/order exceeds supply" );

    for(uint i; i < recipient.length; ++i){
      for(uint j; j < quantity[i]; ++j){
        uint tokenId = supply++;
        _mint( recipient[i], tokenId, types_[i] );
      }
    }
  }

  function setWhitelistAddress(address[] calldata accounts, uint[] calldata allowed) external onlyDelegates{
    require( accounts.length == allowed.length, "MOON: Must provide equal accounts and allowed" );
    for(uint i; i < accounts.length; ++i){
      accessList[ accounts[i] ] = allowed[i];
    }
  }

  function setWhitelistActive(bool isWhitelistActive_) external onlyDelegates{
    require( isWhitelistActive != isWhitelistActive_ , "MOON: New value matches old" );
    isWhitelistActive = isWhitelistActive_;
  }

  function setBaseURI(string calldata prefix, string calldata suffix) external onlyDelegates{
    _tokenURIPrefix = prefix;
    _tokenURISuffix = suffix;
  }

  function setMaxSupply(uint maxSupply) external onlyDelegates{
    require( MAX_SUPPLY != maxSupply, "TENSEI: New value matches old" );
    require( maxSupply >= totalSupply(), "MOON: Specified supply is lower than current balance" );
    MAX_SUPPLY = maxSupply;
  }

  function setPrice(uint price) external onlyDelegates{
    require( PRICE != price, "MOON: New value matches old" );
    PRICE = price;
  }

  function setMoon(uint[] calldata tokenIds, MoonType[] calldata types,
    uint32[] calldata nextBreeds, uint32[] calldata lastStakes ) external onlyDelegates {

    Moon storage moon;
    for(uint i; i < tokenIds.length; ++i ){
      require(_exists(tokenIds[i]), "MOON: Query for nonexistent token");

      moon = moons[tokenIds[i]];
      moon.moonType = types[i];
    }
  }

  //internal
  function _beforeTokenTransfer(address from, address to) internal {
    if( from != address(0) )
      --_balances[ from ];

    if( to != address(0) )
      ++_balances[ to ];
  }

  function _exists(uint tokenId) internal view override returns (bool) {
    return tokenId < moons.length && moons[tokenId].owner != address(0);
  }

  function _mint(address to, uint tokenId, MoonType type_ ) internal {
    _beforeTokenTransfer(address(0), to);
    moons.push(Moon( to, type_));
    emit Transfer(address(0), to, tokenId);
  }

  function _transfer(address from, address to, uint tokenId) internal override {
    require(moons[tokenId].owner == from, "MOON: transfer of token that is not owned");

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);
    _beforeTokenTransfer(from, to);

    moons[tokenId].owner = to;
    emit Transfer(from, to, tokenId);
  }
}