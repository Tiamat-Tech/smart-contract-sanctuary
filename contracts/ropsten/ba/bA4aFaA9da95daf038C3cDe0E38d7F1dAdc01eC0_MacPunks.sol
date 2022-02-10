// SPDX-License-Identifier: MIT

/**
*/

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MacPunks is ERC721, Ownable {
  using Strings for uint256;
  using Counters for Counters.Counter;
  using SafeMath for uint256;

  Counters.Counter private supply;

  string private uriPrefix = "";
  string private uriSuffix = ".json";
  string private hiddenMetadataUri;
  
  uint256 private cost = 0.09 ether;
  uint256 private presaleCost = 0.05 ether;
  uint256 private maxSupply = 1984;
  uint256 private maxMintAmountPerTx = 3;

  bool private paused = true;
  bool private revealed = false;
  bool private presale = false;

  address[] private whitelistedAddresses;
//   mapping(address => uint256) public addressMintedBalance;


  constructor() ERC721("MACPUNKS", "MCPNKS") {
    setHiddenMetadataUri("ipfs://__CID__/hidden.json");
  }

  modifier mintCompliance(uint256 _mintAmount) {
    require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, "Invalid mint amount!");
    require(supply.current() + _mintAmount <= maxSupply, "Max supply exceeded!");
    _;
  }

  function totalSupply() public view returns (uint256) {
    return supply.current();
  }

  function getMaxSupply() public view returns (uint256) {
      return maxSupply;
  }

  function mintCost() public view returns (uint256 _mintCost) {
    return (presale == true) ? presaleCost: cost; 
  }

  function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) {
    require(!paused, "The contract is paused!");
    require(msg.value >= mintCost() * _mintAmount, "Insufficient funds!");
    if(presale == true) {
        require(isWhitelisted(msg.sender), "Sorry, not on the list");
    }
    _mintLoop(msg.sender, _mintAmount);
  }
  
  function mintForAddress(uint256 _mintAmount, address _receiver) public mintCompliance(_mintAmount) onlyOwner {
    _mintLoop(_receiver, _mintAmount);
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
    uint256 currentTokenId = 1;
    uint256 ownedTokenIndex = 0;

    while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
      address currentTokenOwner = ownerOf(currentTokenId);

      if (currentTokenOwner == _owner) {
        ownedTokenIds[ownedTokenIndex] = currentTokenId;

        ownedTokenIndex++;
      }

      currentTokenId++;
    }

    return ownedTokenIds;
  }

  function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(_tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    if (revealed == false) {
      return hiddenMetadataUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : "";
  }

  function setRevealed(bool _state) public onlyOwner {
    revealed = _state;
  }

  function setCost(uint256 _cost) public onlyOwner {
    cost = _cost;
  }

  function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
    maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
    hiddenMetadataUri = _hiddenMetadataUri;
  }

  function setUriPrefix(string memory _uriPrefix) public onlyOwner {
    uriPrefix = _uriPrefix;
  }

  function setUriSuffix(string memory _uriSuffix) public onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setPaused(bool _state) public onlyOwner {
    paused = _state;
  }

  function setPresale(bool _state) public onlyOwner {
      presale = _state;
  }

  function isWhitelisted(address _user) private view returns (bool) {
    for (uint i = 0; i < whitelistedAddresses.length; i++) {
      if (whitelistedAddresses[i] == _user) {
          return true;
      }
    }
    return false;
  }
  
  function whitelistUsers(address[] calldata _users) public onlyOwner {
    delete whitelistedAddresses;
    whitelistedAddresses = _users;
  }


  function withdraw() public onlyOwner {
    // This will transfer the remaining contract balance to the owner.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
    // =============================================================================
  }

  function _mintLoop(address _receiver, uint256 _mintAmount) internal {
    for (uint256 i = 0; i < _mintAmount; i++) {
      supply.increment();
      _safeMint(_receiver, supply.current());
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }
}