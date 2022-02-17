// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import './ERC721A.sol';
import './Utils.sol';

/**
 * @title HappyRobotNFT
 * HappyRobotNFT - ERC721 contract that whitelists an operator address, has create and mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract HappyRobotNFT is ERC721A, Ownable {

  // max sizes for every generation
  uint16 public constant gen0TokenMaxSize = 3333;
  uint16 public constant gen1TokenMaxSize = 3334;
  
  // constant value for every generation
  uint8 public constant GENERATION0 = 0;
  uint8 public constant GENERATION1 = 1;

  uint8 constant LAST_FLOOR = 10;
  
  // happy robot nft attributes
  struct Attribute {
    uint16  neuronDayStamp; // day value of timestamp = timestamp / (24 * 60 * 60),
                          // when minting NFT, this value is set with the day value of current timestamp
    uint8   currentFloor; // current floor value: from 1 to 10
    uint16  totalTime; // total seconds which the nft passed floors
  }

  address proxyRegistryAddress;

  uint16 private gen0TokenCounter = 0;
  uint16 private gen1TokenCounter = 0;

  mapping(uint256 => Attribute) private attribute; // attribute of happy robot nft
  mapping(uint256 => uint8) private genMap; // generation map token vs generation
  
  // base uri
  string private baseURI;

  constructor(address _proxyRegistryAddress) ERC721A("Happy Robot", "HappyRobot") {
    proxyRegistryAddress = _proxyRegistryAddress;
  }

  /**
   * Will update the base URL of token's URI
   * @param _newBaseURI New base URL of token's URI
   */
  function setBaseURI(
    string memory _newBaseURI
  ) public onlyOwner {
    baseURI = _newBaseURI;
  }

  /**
   * get base uri 
   * @return base uri
   */
  function _baseURI() internal view override returns (string memory) {
      return baseURI;
  }

  /**
  * get generation value list of NFTs
  * @return generation value list of NFTs
  */
  function getGenMap() public view returns (uint256[] memory) {
    uint256 len = totalSupply();
    uint256[] memory genList = new uint256[](len);
    for (uint256 i = 0; i < len; i++) {
      genList[i] = genMap[i];
    }

    return genList;
  }

  /**
   * Check if token can be created 
   * @param _genIndex generation option
   * @param _quantity quantity
   * @return true or false
   */
  function canCreateToken(uint8 _genIndex, uint16 _quantity) public view returns (bool) {
    if (_genIndex == GENERATION0) {
      if (gen0TokenCounter + _quantity >= gen0TokenMaxSize)
        return false;

    } else if (_genIndex == GENERATION1) {
      if (gen1TokenCounter >= gen1TokenMaxSize)
        return false;

    } else {
      return false;
    }

    return true;
  }

  /**
   * reset attribute values for NFT
   * @param _id token id
   */
  function _resetAttribute(uint256 _id) internal {
    uint16 neuronDayStamp = uint16(block.timestamp / (24 * 60 * 60));
    Attribute memory attr = Attribute(neuronDayStamp, 1, 0);

    attribute[_id] = attr;
  }

  /**
  * get token id list of owner
  * @param _owner the owner of token
  * @return token id list
  */
  function getTokenIdsOfOwner(address _owner) public view returns (uint256[] memory) {
    uint256 numMintedSoFar = totalSupply();
    address currOwnershipAddr;

    // Counter overflow is impossible as the loop breaks when uint256 i is equal to another uint256 numMintedSoFar.
    uint8 tokenCounter = 0;

    // get counter of tokens
    for (uint256 i; i < numMintedSoFar; i++) {
      TokenOwnership memory ownership = _ownerships[i];
      if (ownership.addr != address(0)) {
        currOwnershipAddr = ownership.addr;
      }
      if (currOwnershipAddr == _owner) {
        tokenCounter++;
      }
    }

    // configure token id list
    uint256[] memory tokenIds = new uint256[](tokenCounter);
    uint8 index = 0;
    for (uint256 i; i < numMintedSoFar; i++) {
      TokenOwnership memory ownership = _ownerships[i];
      if (ownership.addr != address(0)) {
        currOwnershipAddr = ownership.addr;
      }
      if (currOwnershipAddr == _owner) {
        tokenIds[index] = i;
        index++;
      }
    }

    return tokenIds;
  }

  /**
  * update the floor information
  * @param _owner owner of NFT
  * @param _id id of NFT
  * @param _floor passed floor
  * @param _passTime total seconds that was taken the floor
  */
  function passedFloor(address _owner,  uint256 _id, uint8 _floor, uint16 _passTime) public onlyOwner {
    if (_floor >= LAST_FLOOR) return;

    require(_owner == ownerOf(_id), "You can unlock the floor for only your NFT.");
    attribute[_id].currentFloor = _floor + 1;
    attribute[_id].totalTime += _passTime;
  }

  /**
    * mint a new NFT token 
    * NOTE: remove onlyOwner if you want third parties to create new tokens on your contract (which may change your IDs)
    * @param _owner address of the first owner of the token
    * @param _genIndex generation index
    * @param _quantity quantity
    * @param _data Data to pass if receiver is contract
    */
  function mint(
    address _owner,
    uint8 _genIndex,
    uint16 _quantity,
    bytes calldata _data
  ) external onlyOwner {

    uint256 preIndex = currentIndex;
    _safeMint(_owner, _quantity, _data);

    if (_genIndex == GENERATION0)
      gen0TokenCounter += _quantity;
    else if (_genIndex == GENERATION1)
      gen1TokenCounter += _quantity;
    
    // initialize attribute for NFT
    for (uint256 i = preIndex; i < currentIndex; i++) {
      _resetAttribute(i);
      genMap[i] = _genIndex;
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

    return ERC721A.isApprovedForAll(_owner, _operator);
  }

  /**
  * claim neurons
  * @param _id id of NFT
  * @param _owner owner of token
  * @param _neurons the amount of neuron to claim
  * @return claimed neurons
  */
  function claimNeurons(address _owner, uint256 _id, uint16 _neurons) public onlyOwner returns(uint16) {
    require(_owner == ownerOf(_id), "You can claim neurons for only your NFT.");

    uint16 curDayStamp = uint16(block.timestamp / (24 * 60 * 60));
    uint16 neurons = curDayStamp - attribute[_id].neuronDayStamp;

    if (neurons < _neurons) {
      attribute[_id].neuronDayStamp = curDayStamp;
      return neurons;

    }

    attribute[_id].neuronDayStamp += _neurons;

    return _neurons;
  }

  /**
  * get neurons of NFT
  * @param _id id of NFT
  * @return neurons
  */
  function getNeurons(uint256 _id) public view returns (uint16) {
    uint16 curDayStamp = uint16(block.timestamp / (24 * 60 * 60));
    return curDayStamp - attribute[_id].neuronDayStamp;
  }

  /**
  * get attribute of NFT
  * @param _id id of NFT
  * @return attribute of NFT
  */
  function getAttribute(uint256 _id) public view returns (Attribute memory) {
    Attribute memory attr = Attribute(attribute[_id].neuronDayStamp, attribute[_id].currentFloor, attribute[_id].totalTime);
    return attr;
  }

  /**
  * get attribute list of NFTs
  * @return attribute list of NFTs
  */
  function getTotalAttributes() public view returns (Attribute[] memory) {
    uint256 len = totalSupply();
    Attribute[] memory attrList = new Attribute[](len);

    for (uint256 i = 0; i < len; i++) {
      attrList[i] = attribute[i];
    }

    return attrList;
  }

  /**
   * @notice Transfers token of an _id from the _from address to the _to address specified
   * @param _from    Source address
   * @param _to      Target address
   * @param _id      ID of the token
   */
  function transferFrom(
      address _from,
      address _to,
      uint256 _id
  ) public virtual override {
    ERC721A.transferFrom(_from, _to, _id);

    // reset neuron value
    attribute[_id].neuronDayStamp = uint16(block.timestamp / (24 * 60 * 60));
  }
  
  /**
   * @notice Transfers token of an _id from the _from address to the _to address specified
   * @param _from    Source address
   * @param _to      Target address
   * @param _id      ID of the token
   * @param _data    data of the token
   */
  function safeTransferFrom(
    address _from, 
    address _to, 
    uint256 _id,
    bytes memory _data
    ) public virtual override {
    
    ERC721A.safeTransferFrom(_from, _to, _id, _data);

    // reset neuron value
    attribute[_id].neuronDayStamp = uint16(block.timestamp / (24 * 60 * 60));
  }
}