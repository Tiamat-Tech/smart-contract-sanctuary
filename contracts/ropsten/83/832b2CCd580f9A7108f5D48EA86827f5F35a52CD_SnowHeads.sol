// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Verifiable {
    /* 1. Unlock MetaMask account
    ethereum.enable()
    */

    /* 2. Get message hash to sign
    getMessageHash(
        0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C,
        123,
        "coffee and donuts",
        1
    )

    hash = "0xcf36ac4f97dc10d91fc2cbb20d718e94a8cbfe0f82eaedc6a4aa38946fb797cd"
    */
    function getMessageHash(
        string memory _code,
        string memory _method
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_code, _method));
    }

    function getMessageHashWithAddress(
      string memory _code,
      string memory _method,
      address user
    ) public pure returns(bytes32) {
      return keccak256(abi.encodePacked(_code, _method, user));
    }

    function verifySignature(
      bytes32 _message,
      bytes memory _signature,
      address _signer
    ) public pure returns (bool) {
      (address recoveredSigner, ECDSA.RecoverError error) = ECDSA.tryRecover(
        ECDSA.toEthSignedMessageHash(_message),
        _signature
      );

      if (error == ECDSA.RecoverError.NoError && recoveredSigner == _signer) {
        return true;
      } else {
        return false;
      }
    }
}

contract SnowHeads is Ownable, ERC721Enumerable, Verifiable {
  using Strings for uint256;

  bool public isMintActive;
  string public baseURI;
  uint256 public presaleStartAt;
  uint public mintPrice = 0.035 ether;
  mapping(string => bool) public _usedCoupons;
  uint public givenAwaySnowheads = 0;
  uint public mintedSnowheads = 0;

  uint256 constant PRESALE_DURATION = 86400; // 1 day in seconds
  uint constant TOTAL_SUPPLY = 5555;
  uint constant MAX_PER_PURCHASE = 5;
  uint constant GIVEAWAY_POOL = 170;

  uint public REVEAL_TIMESTAMP;

  // settable only once, to be assigned after reveal
  string public SNOWHEAD_PROVENANCE;

  uint public startingIndexBlock;
  uint public startingIndex;

  constructor(
    bool _isMintActive,
    string memory _newURI,
    uint _presaleStartAt,
    uint _revealTimestamp
  ) ERC721("SnowHeads", "SH") {
    isMintActive = _isMintActive;
    baseURI = _newURI;
    presaleStartAt = _presaleStartAt;
    REVEAL_TIMESTAMP = _revealTimestamp;
  }

  modifier presaleOngoing() {
    require(block.timestamp >= presaleStartAt, "Snowheads: Presale has not started yet");
    require(block.timestamp <= presaleStartAt + PRESALE_DURATION, "Snowheads: Presale already ended");
    _;
  }

  modifier validSignature(
    string memory _couponCode,
    string memory _method,
    bytes memory _signature
  ) {
    require(
      verifySignature(
        getMessageHash(_couponCode, _method),
        _signature,
        owner()
      ),
      "Snowheads: Invalid Signature"
    );

    require(!_usedCoupons[_couponCode], "Snowheads: Coupon code already used");
    _;
  }

  modifier validSignatureForFreeMint(
    string memory _couponCode,
    address _user,
    bytes memory _signature
  ) {
    require(
      verifySignature(
          getMessageHashWithAddress(_couponCode, "freeMint", _user),
          _signature,
          owner()
      ),
      "Snowheads: Invalid Free Mint Signature"
    );

    require(!_usedCoupons[_couponCode], "Snowheads: Coupon code already used");
    _;
  }

  function setIsMintActive(bool _isMintActive) public onlyOwner {
    isMintActive = _isMintActive;
  }

  function _mintSnowheads(address to, uint _numTokens, uint _mintedSoFar) internal {
    for (uint i = 0; i < _numTokens; i++) {
      _safeMint(to, _mintedSoFar + i);
    }

    setStartingBlock(_mintedSoFar + _numTokens);
  }

  function mint(uint _numTokens) public payable {
    require(isMintActive, "Snowheads: Sale is not active");

    uint mintedSoFar = mintedSnowheads + GIVEAWAY_POOL;
    require(_numTokens > 0 && _numTokens <= MAX_PER_PURCHASE, "Snowheads: Invalid number of Snowheads!");
    require(mintedSoFar + _numTokens <= TOTAL_SUPPLY, "Snowheads: Not enough tokens left!");
    require(msg.value >= mintPrice * _numTokens, "Snowheads: Not enough funds!");
    _mintSnowheads(_msgSender(), _numTokens, mintedSoFar);
    mintedSnowheads += _numTokens;
  }

  function freeMint(
    string memory _couponCode,
    bytes memory _signature
  )
  public
  presaleOngoing
  validSignatureForFreeMint(_couponCode, _msgSender(), _signature)
  {
    uint mintedSoFar = mintedSnowheads + GIVEAWAY_POOL;
    require(mintedSoFar < TOTAL_SUPPLY, "Snowheads: Not enough tokens left!");
    _mintSnowheads(_msgSender(), 1, mintedSoFar);
    _usedCoupons[_couponCode] = true;
    mintedSnowheads += 1;
  }

  function presaleMint(
    string memory _presalePass,
    bytes memory _signature
  ) public
    payable
    presaleOngoing
    validSignature(_presalePass, "presaleMint", _signature) {
      uint mintedSoFar = mintedSnowheads + GIVEAWAY_POOL;
      require(mintedSoFar < TOTAL_SUPPLY, "Snowheads: Not enough tokens left!");
      require(msg.value >= mintPrice, "Snowheads: Not enough funds!");
      _mintSnowheads(_msgSender(), 1, mintedSoFar);
      _usedCoupons[_presalePass] = true;
      mintedSnowheads += 1;
    }

  function SnowheadsOfOwner(address owner) public view returns (uint[] memory) {
    uint balance = balanceOf(owner);
    uint[] memory wallet = new uint[](balance);

    for (uint i = 0; i < balance; i++) {
      wallet[i] = tokenOfOwnerByIndex(owner, i);
    }

    return wallet;
  }

  function giveaway(address _receiver, uint _numTokens) public onlyOwner {
    require(givenAwaySnowheads + _numTokens <= GIVEAWAY_POOL, "Snowheads: Not enough tokens left!");
    _mintSnowheads(_receiver, _numTokens, givenAwaySnowheads);
    givenAwaySnowheads += _numTokens;
  }

  function ownsAllTokens(address _owner, uint[] memory _tokenIds) public view returns (bool) {
    for (uint i = 0; i < _tokenIds.length; i++) {
      uint tokenIndex = _tokenIds[i];
      if (ownerOf(tokenIndex) != _owner) {
        return false;
      }
    }

    return true;
  }

  function exists(uint id) public view returns (bool) {
    return _exists(id);
  }

  function setBaseURI(string memory _newURI)
    public
    onlyOwner
  {
    baseURI = _newURI;
  }

  function setMintPrice(uint _mintPrice) public onlyOwner {
    mintPrice = _mintPrice;
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  function isValidSignature(
    string memory _couponCode,
    string memory _method,
    bytes memory _signature
  )
  public
  view
  validSignature(_couponCode, _method, _signature)
  returns (bool)
  {
    return true;
  }

  function isValidFreeMintSignature(
    string memory _couponCode,
    address _user,
    bytes memory _signature
  ) public
    view
    validSignatureForFreeMint(_couponCode, _user, _signature)
    returns (bool)
  {
      return true;
  }

  function withdraw() public payable onlyOwner {
    uint balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  function setProvenanceHash(string memory _provenance) public onlyOwner {
    require(bytes(SNOWHEAD_PROVENANCE).length == 0, "Snowheads: Provenance already set");
    SNOWHEAD_PROVENANCE = _provenance;
  }

  function setStartingIndex() public {
    require(startingIndex == 0, "Starting index is already set");
    require(startingIndexBlock != 0, "Starting index block must be set");

    startingIndex = uint(blockhash(startingIndexBlock)) % TOTAL_SUPPLY;
    // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
    if (block.number - startingIndexBlock > 255) {
        startingIndex = uint(blockhash(block.number - 1)) % TOTAL_SUPPLY;
    }

    // Prevent default sequence
    if (startingIndex == 0) {
        startingIndex = startingIndex + 1;
    }
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    uint256 artId = (tokenId + startingIndex) % TOTAL_SUPPLY;
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, artId.toString())) : "";
  }

  function setStartingBlock(uint _mintedSoFar) internal {
    if (startingIndexBlock == 0 && (_mintedSoFar == TOTAL_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
      startingIndexBlock = block.number;
    }
  }
}