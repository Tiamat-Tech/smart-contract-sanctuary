// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
// import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import './ERC1155A.sol';
import './Utils.sol';

/**
 * @title ChlngrBrandNFT
 * ChlngrBrandNFT - ERC1155 contract that whitelists an operator address, has create and mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract ChlngrBrandNFT is ERC1155A, Ownable {

  // max sizes for every generation
  uint16 constant gen0TokenMaxSize = 333;
  uint16 constant gen1TokenMaxSize = 3000;
  uint16 constant gen2TokenMaxSize = 3333;

  // base ids of token for every generation
  uint8  constant gen0TokenBaseID = 0;
  uint16 constant gen1TokenBaseID = 1000;
  uint16 constant gen2TokenBaseID = 5000;
  
  // constant value for every generation
  uint8 public constant GENERATION0 = 0;
  uint8 public constant GENERATION1 = 1;
  uint8 public constant GENERATION2 = 2;

  // tokin price constant
  uint256 constant TOKIN_PRICE = 0.0001 ether;

  uint8 constant LAST_FLOOR = 10;
  uint8 constant MIDDLE_FLOOR = 8;
  uint8 constant FIRST_LEVEL_TOKINS = 30;
  uint8 constant SECOND_LEVEL_TOKINS = 50;
  
  // chlngr brand nft attributes
  struct Attribute {
    uint16  tokinDayStamp; // day value of timestamp = timestamp / (24 * 60 * 60),
                          // when minting NFT, this value is set with the day value of current timestamp
    uint8   currentFloor; // current floor value: from 1 to 10
    uint16  totalTime; // total seconds which the nft passed floors
  }

  address proxyRegistryAddress;

  mapping (uint16 => address) private _owners;
  mapping(uint16 => string) internal _tokenURIs;

  uint16 private _gen0TokenCounter = 0;
  uint16 private _gen1TokenCounter = 0;
  uint16 private _gen2TokenCounter = 0;

  mapping (uint16 => Attribute) private _attribute; // attribute of chlngr brand nft
  
  // Contract name
  string public name;

  // Contract symbol
  string public symbol;

  // tokin price variable
  uint256 private _tokinPrice = TOKIN_PRICE;

  /**
   * @dev Require msg.sender to be the creator of the token id
   */
  modifier creatorOnly(uint16 _id) {
    require(_owners[_id] == msg.sender, "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED");
    _;
  }

  constructor(address _proxyRegistryAddress) {
    name = "Chlngr Brand";
    symbol = "CHLNGRBRAND";
    proxyRegistryAddress = _proxyRegistryAddress;
  }

  /**
  * get uri of NFT
  * @param _id id of NFT
  * @return 
  */
  function uri(
    uint16 _id
  ) public view returns (string memory) {
    require(_exists(_id), "uri: NONEXISTENT_TOKEN");
    return _tokenURIs[_id];
  }

  /**
    * @dev Returns the total NFT quantity
    * @return amount of NFT in existence
  */
  function totalSupply() public view returns (uint16) {
    return _gen0TokenCounter + _gen1TokenCounter + _gen2TokenCounter;
  }

  /**
   * @dev Will update the base URL of token's URI
   * @param _newBaseMetadataURI New base URL of token's URI
   */
  // function setBaseMetadataURI(
  //   string memory _newBaseMetadataURI
  // ) public onlyOwner {
  //   _setBaseMetadataURI(_newBaseMetadataURI);
  // }

  /**
   * @dev get the number of tokens that the owner owned
   * @param _owner owner
   * @return The number of tokens
   */
  function getTokenCountOfOwner(address _owner) public view returns (uint8) {
    uint8 count = 0;
    for (uint16 i = 1; i <= _gen0TokenCounter; i++) {
      if (_owners[i + gen0TokenBaseID] == _owner)
        count++;
    }

    for (uint16 i = 1; i <= _gen1TokenCounter; i++) {
      if (_owners[i + gen1TokenBaseID] == _owner)
        count++;
    }

    for (uint16 i = 1; i <= _gen2TokenCounter; i++) {
      if (_owners[i + gen2TokenBaseID] == _owner)
        count++;
    }
    return count;
  }

  /**
   * @dev Check if token can be created 
   * @param _genIndex generation option
    * @return true or false
   */
  function canCreateToken(uint8 _genIndex) public view returns (bool) {
    if (_genIndex == GENERATION0) {
      if (_gen0TokenCounter >= gen0TokenMaxSize)
        return false;

    } else if (_genIndex == GENERATION1) {
      if (_gen1TokenCounter >= gen1TokenMaxSize)
        return false;

    } else if (_genIndex == GENERATION2) {
      if (_gen2TokenCounter >= gen2TokenMaxSize)
        return false;      

    } else {
      return false;
    }

    return true;
  }

  /**
   * @dev reset attribute values for NFT
   * @param _id token id
   */
  function _resetAttribute(uint16 _id) internal {
    uint16 tokinDayStamp = uint16(block.timestamp / (24 * 60 * 60));
    Attribute memory attr = Attribute(tokinDayStamp, 1, 0);

    _attribute[_id] = attr;
  }

  /**
  * update and unlock floor
  * @param _id id of NFT
  * @param _floor passed floor
  * @param _passTime total seconds that was taken the floor
  */
  function updateFloor(uint16 _id, uint8 _floor, uint16 _passTime) public {
    require(msg.sender == _owners[_id], "You can unlock the floor for only your NFT.");

    _attribute[_id].currentFloor = _floor + 1;
    _attribute[_id].totalTime += _passTime;

    if (_floor >= LAST_FLOOR) return;

    uint8 reqTokins = FIRST_LEVEL_TOKINS;
    if (_floor >= MIDDLE_FLOOR) 
      reqTokins = SECOND_LEVEL_TOKINS;

    require(_attribute[_id].tokinDayStamp >= reqTokins, "Your tokins are not enough to unlock next level");
    _attribute[_id].tokinDayStamp += reqTokins;
  }

  /**
    * @dev mint a new NFT token 
    * NOTE: remove onlyOwner if you want third parties to create new tokens on your contract (which may change your IDs)
    * @param _owner address of the first owner of the token
    * @param _genIndex generation index
    * @param _uri Optional URI for this token type
    * @param _data Data to pass if receiver is contract
    * @return The newly created token ID
    */
  function mint(
    address _owner,
    uint8 _genIndex,
    string calldata _uri,
    bytes calldata _data
  ) external onlyOwner returns (uint256) {

    uint16 _id = _getNextTokenID(_genIndex);
    _owners[_id] = msg.sender;
    _tokenURIs[_id] = _uri;
    
    // initialize attribute for NFT
    _resetAttribute(_id);

    if (bytes(_uri).length > 0) {
      emit URI(_uri, _id);
    }

    // mint
    _mint(_owner, _id, 1, _data);
    return _id;
  }

  /**
    * @dev Change the creator address for given tokens
    * @param _to   Address of the new creator
    * @param _ids  Array of Token IDs to change creator
    */
  function setCreator(
    address _to,
    uint16[] memory _ids
  ) public {
    require(_to != address(0), "ERC1155Tradable#setCreator: INVALID_ADDRESS.");
    for (uint256 i = 0; i < _ids.length; i++) {
      uint16 id = _ids[i];
      _setCreator(_to, id);
    }
  }

  /**
   * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-free listings.
   */
  function isApprovedForAll(address _owner, address _operator) public view override returns (bool isOperator) {
    // Whitelist OpenSea proxy contract for easy trading.
    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    if (address(proxyRegistry.proxies(_owner)) == _operator) {
      return true;
    }

    return ERC1155A.isApprovedForAll(_owner, _operator);
  }

  /**
    * @dev Change the creator address for given token
    * @param _to   Address of the new creator
    * @param _id  Token IDs to change creator of
    */
  function _setCreator(address _to, uint16 _id) internal creatorOnly(_id)
  {
      _owners[_id] = _to;
  }

  /**
    * @dev Returns whether the specified token exists by checking to see if it has a creator
    * @param _id uint256 ID of the token to query the existence of
    * @return bool whether the token exists
    */
  function _exists(
    uint16 _id
  ) internal view returns (bool) {
    return _owners[_id] != address(0);
  }

  /**
    * @dev calculates the next token ID based on value of generation option
    * @param _genIndex generation index
    * @return uint16 for the next token ID
    */
  function _getNextTokenID(uint8 _genIndex) private returns (uint16) {
    if (_genIndex == GENERATION0) {
      _gen0TokenCounter++;
      return _gen0TokenCounter + gen0TokenBaseID;

    } else if (_genIndex == GENERATION1) {
      _gen1TokenCounter++;
      return _gen1TokenCounter + gen1TokenBaseID;

    } else if (_genIndex == GENERATION2) {
      _gen2TokenCounter++;
      return _gen2TokenCounter + gen2TokenBaseID;
    }

    return 0;
  }

  /**
  * get tokin price
  * @return the price of 1 tokin
  */
  function tokinPrice() public view returns (uint256) {
    return _tokinPrice;
  }

  /**
  * update tokin price
  * @param _price update the price of 1 tokin
  */
  function updateTokinPrice(uint16 _price) public onlyOwner {
    _tokinPrice = _price;
  }

  /**
  * deposit tokins
  * @param _id id of NFT
  * @param _tokins the number of tokin
  */
  function depositTokins(uint16 _id, uint16 _tokins) public {
    require(msg.sender == _owners[_id], "You can deposit tokins for only your NFT.");

    _attribute[_id].tokinDayStamp -= _tokins;

    // deposite ether part
  }

  /**
  * claimTokins
  * @param _id id of NFT
  * @param _tokins the number of tokin
  */
  function claimTokins(uint16 _id, uint16 _tokins) public {
    require(msg.sender == _owners[_id], "You can claim tokins for only your NFT.");

    require(_attribute[_id].tokinDayStamp >= _tokins, "Not enough tokins to claim");

    _attribute[_id].tokinDayStamp += _tokins;

    // claim ether part
  }

  /**
  * get attribute of NFT
  * @param _id id of NFT
  * @return attribute of NFT
  */
  function getAttribute(uint16 _id) public view returns (Attribute memory) {
    Attribute memory attr = Attribute(_attribute[_id].tokinDayStamp, _attribute[_id].currentFloor, _attribute[_id].totalTime);
    return attr;
  }

  /**
  * get attribute list of NFTs
  * @return attribute list of NFTs
  */
  function getTotalAttributes() public view returns (Attribute[] memory) {
    uint16 len = totalSupply();
    Attribute[] memory attrList = new Attribute[](len);

    uint16 index = 0;
    for (uint16 i = 1; i <= _gen0TokenCounter; i++) {
      attrList[index] = _attribute[i + gen0TokenBaseID];
      index++;
    }

    for (uint16 i = 1; i <= _gen1TokenCounter; i++) {
      attrList[index] = _attribute[i + gen1TokenBaseID];
      index++;
    }

    for (uint16 i = 1; i <= _gen2TokenCounter; i++) {
      attrList[index] = _attribute[i + gen2TokenBaseID];
      index++;
    }

    return attrList;
  }
  
  /**
   * @notice Transfers amount amount of an _id from the _from address to the _to address specified
   * @param _from    Source address
   * @param _to      Target address
   * @param _id      ID of the token type
   * @param _amount  Transfered amount
   * @param _data    Additional data with no specified format, sent in call to `_to`
   */
  function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data)
    public override onlyOwner
  {
    ERC1155A.safeTransferFrom(_from, _to, _id, 1, _data);

    // change owner of token
    _owners[uint16(_id)] = _to;

    // reset attribute of token
    _resetAttribute(uint16(_id));
  }
}