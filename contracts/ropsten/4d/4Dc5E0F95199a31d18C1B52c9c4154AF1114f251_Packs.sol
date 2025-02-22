// SPDX-License-Identifier: MIT
// Written by Tim Kang <> illestrater
// Thought innovation by Monstercat
// Product by universe.xyz

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IPacks.sol";
import "./LibPackStorage.sol";

contract Packs is IPacks, ERC721, ReentrancyGuard {
  using SafeMath for uint256;

  constructor(
    string memory name,
    string memory symbol,
    string memory _baseURI,
    bool _editioned,
    uint256[] memory _initParams,
    string memory _licenseURI,
    address _mintPass,
    uint256 _mintPassDuration,
    bool _mintPassOnePerWallet
  ) ERC721(name, symbol) {
    require(_initParams[1] <= 50, "Bulk buy limit of 50");

    LibPackStorage.Storage storage ds = LibPackStorage.packStorage();

    ds.daoAddress = msg.sender;
    ds.daoInitialized = true;
    ds.collectionCount = 1;

    ds.collection[0].baseURI = _baseURI;
    ds.collection[0].editioned = _editioned;
    ds.collection[0].tokenPrice = _initParams[0];
    ds.collection[0].bulkBuyLimit = _initParams[1];
    ds.collection[0].saleStartTime = _initParams[2];
    ds.collection[0].licenseURI[0] = _licenseURI;
    ds.collection[0].licenseVersion = 1;

    if (_mintPass != address(0)) {
      ds.collection[0].mintPass = true;
      ds.collection[0].mintPassOnePerWallet = _mintPassOnePerWallet;
      ds.collection[0].mintPassContract = ERC721(_mintPass);
      ds.collection[0].mintPassDuration = _mintPassDuration;
    }

    _setBaseURI(_baseURI);
  }

  bytes4 private constant _INTERFACE_ID_ROYALTIES_RARIBLE = 0xb7799584;
  bytes4 private constant _INTERFACE_ID_ROYALTIES_EIP2981 = 0x2a55205a;

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
    return interfaceId == _INTERFACE_ID_ROYALTIES_RARIBLE || interfaceId == _INTERFACE_ID_ROYALTIES_EIP2981 || super.supportsInterface(interfaceId);
  }

  modifier onlyDAO() {
    LibPackStorage.Storage storage ds = LibPackStorage.packStorage();
    require(msg.sender == ds.daoAddress, "Wrong address");
    _;
  }

  function transferDAOownership(address payable _daoAddress) public override onlyDAO {
    LibPackStorage.Storage storage ds = LibPackStorage.packStorage();
    ds.daoAddress = _daoAddress;
    ds.daoInitialized = true;
  }

  function createNewCollection(string memory _baseURI, bool _editioned, uint256[] memory _initParams, string memory _licenseURI, address _mintPass, uint256 _mintPassDuration, bool _mintPassOnePerWallet) public override onlyDAO {
    LibPackStorage.createNewCollection(_baseURI, _editioned, _initParams, _licenseURI, _mintPass, _mintPassDuration, _mintPassOnePerWallet);
  }

  function addCollectible(uint256 cID, string[] memory _coreData, string[] memory _assets, string[][] memory _metadataValues, string[][] memory _secondaryMetadata, LibPackStorage.Fee[] memory _fees) public override onlyDAO {
    require(_coreData.length == 4, 'Core data misformatted');
    LibPackStorage.addCollectible(cID, _coreData, _assets, _metadataValues, _secondaryMetadata, _fees);
  }

  function bulkAddCollectible(uint256 cID, string[][] memory _coreData, string[][] memory _assets, string[][][] memory _metadataValues, string[][][] memory _secondaryMetadata, LibPackStorage.Fee[][] memory _fees) public override onlyDAO {
    for (uint256 i = 0; i < _coreData.length; i++) {
      addCollectible(cID, _coreData[i], _assets[i], _metadataValues[i], _secondaryMetadata[i],  _fees[i]);
    }
  }

  function randomTokenID(uint256 cID) private returns (uint256) {
    LibPackStorage.Storage storage ds = LibPackStorage.packStorage();

    (uint256 randomID, uint256 tokenID) = LibPackStorage.randomTokenID(cID);

    ds.collection[cID].shuffleIDs[randomID] = ds.collection[cID].shuffleIDs[ds.collection[cID].shuffleIDs.length - 1];
    ds.collection[cID].shuffleIDs.pop();

    return tokenID;
  }

  function mintPack(uint256 cID) public override payable nonReentrant {
    LibPackStorage.Storage storage ds = LibPackStorage.packStorage();
    bool freeClaim = LibPackStorage.canFreeClaim(cID, msg.sender);
    LibPackStorage.mintChecks(cID, freeClaim);
 
    uint256 excessAmount;
    if (!freeClaim) excessAmount = msg.value.sub(ds.collection[cID].tokenPrice);
    else excessAmount = msg.value.sub(0);

    if (excessAmount > 0) {
      (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
      require(returnExcessStatus, "Failed to return excess.");
    }

    uint256 tokenID = randomTokenID(cID);
    _mint(_msgSender(), tokenID);
  }

  function bulkMintPack(uint256 cID, uint256 amount) public override payable nonReentrant {
    require(amount > 0, 'Please provide an amount');
    LibPackStorage.Storage storage ds = LibPackStorage.packStorage();

    LibPackStorage.bulkMintChecks(cID, amount);

    uint256 excessAmount = msg.value.sub(ds.collection[cID].tokenPrice.mul(amount));
    if (excessAmount > 0) {
      (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
      require(returnExcessStatus, "Failed to return excess.");
    }

    for (uint256 i = 0; i < amount; i++) {
      uint256 tokenID = randomTokenID(cID);
      _mint(_msgSender(), tokenID);
    }
  }

  function remainingTokens(uint256 cID) public override view returns (uint256) {
    return LibPackStorage.remainingTokens(cID);
  }

  function updateMetadata(uint256 cID, uint256 collectibleId, uint256 propertyIndex, string memory value) public override onlyDAO {
    LibPackStorage.updateMetadata(cID, collectibleId, propertyIndex, value);
  }

  function addVersion(uint256 cID, uint256 collectibleId, string memory asset) public override onlyDAO {
    LibPackStorage.addVersion(cID, collectibleId, asset);
  }

  function updateVersion(uint256 cID, uint256 collectibleId, uint256 versionNumber) public override onlyDAO {
    LibPackStorage.updateVersion(cID, collectibleId, versionNumber);
  }

  function addNewLicense(uint256 cID, string memory _license) public override onlyDAO {
    LibPackStorage.addNewLicense(cID, _license);
  }

  function getLicense(uint256 cID) public override view returns (string memory) {
    return LibPackStorage.getLicense(cID);
  }

  function getLicenseVersion(uint256 cID, uint256 versionNumber) public override view returns (string memory) {
    return LibPackStorage.getLicenseVersion(cID, versionNumber);
  }

  function getCollectionCount() public override view returns (uint256) {
    return LibPackStorage.packStorage().collectionCount;
  }

  function tokenURI(uint256 tokenId) public view virtual override(ERC721, IPacks) returns (string memory) {
    return LibPackStorage.tokenURI(tokenId);
  }

  function getFeeRecipients(uint256 tokenId) public override view returns (address payable[] memory) {
    require(_exists(tokenId), "Nonexistent token");
    return LibPackStorage.getFeeRecipients(tokenId);
  }

  function getFeeBps(uint256 tokenId) public override view returns (uint256[] memory) {
    require(_exists(tokenId), "Nonexistent token");
    return LibPackStorage.getFeeBps(tokenId);
  }

  function royaltyInfo(uint256 tokenId, uint256 value) public override view returns (address recipient, uint256 amount){
    require(_exists(tokenId), "Nonexistent token");
    return LibPackStorage.royaltyInfo(tokenId, value);
  }

  function withdraw(address _to, uint amount) public onlyDAO {
    payable(_to).call{value:amount, gas:200000}("");
  }
}