// SPDX-License-Identifier: ISC
pragma solidity >=0.8.0 <0.9.0;

// import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/NFT.sol";
import "./utils/Taxes.sol";
import "./Splits.sol";

/// @title MonumentArtifacts Contract
/// @author [email protected]
/// @notice This contract shall be the prime Monument NFT contract consisting of all the Artifacts in the Metaverse.
contract MonumentArtifacts is NFT, Taxes, ReentrancyGuard {
  // PermissionManagement internal permissionManagement; <- No need for this as `permissionManagement` is already accessible from the `NFT`.




  /// @notice Constructor function for the MonumentArtifacts Contract
  /// @dev Constructor function for the MonumentArtifacts ERC721 Contract
  /// @param name_ Name of the Monument Artefact Collection
  /// @param symbol_ Symbol for the Monument
  /// @param _permissionManagementContractAddress Address of the PermissionManagement Contract that manages Permissions.
  constructor(
    string memory name_, 
    string memory symbol_,
    address _permissionManagementContractAddress
  )
  NFT(name_, symbol_, _permissionManagementContractAddress)
  Taxes(_permissionManagementContractAddress)
  payable
  {
    // Build Genesis Monument
    _buildMonument("https://monument.app/monuments/0");

    // Build Genesis Artifact and Zero Token
    _mintArtifact(0, "https://monument.app/artifacts/0", 1);
  }




  // token IDs counter
  using Counters for Counters.Counter;
  Counters.Counter public _monumentIDs;
  Counters.Counter public _artifactIDs;
  Counters.Counter public _tokenIDs;




  // Monument
  struct Monument {
    uint256 id;
    string metadata;
    uint256 timestamp;
    address founder;
  }
  Monument[] public monuments;
  mapping(uint256 => uint256[]) public getArtifactIDsByMonumentID;
  mapping(uint256 => uint256[]) public getTokenIDsByMonumentID;

  // Monument Metadata Mapping
  mapping(string => bool) public monumentMetadataExists;
  mapping(string => uint256) public getMonumentIDByMetadata;

  // Monument Fork Data
  mapping(uint256 => uint256[]) public getForksOfMonument;
  mapping(uint256 => uint256) public getMonumentForkedFrom;

  // Monument Founders and Editors
  mapping(address => uint256[]) public getMonumentIDsByFounder;
  mapping(address => uint256[]) public getMonumentIDsByEditor; // `getMonumentIDsByEditor` ↓
  mapping(uint256 => address[]) public getEditorsByMonumentID; // & `getEditorsByMonumentID` logs the editors added, but when mods are removed, the arrays still have them stored in the list. Therefore, when verifying if someone is truly a mod, use `isEditorOfMonumentID`.
  mapping(address => mapping(uint256 => bool)) public isEditorOfMonumentID; // to truly verify if an address is a editor of a monument, `isEditorOfMonumentID` is the only true source.



  // Artifacts
  struct Artifact {
    uint256 id;
    uint256 monumentId;
    string metadata;
    uint256 supply; // editions
    uint256 timestamp;
    address author;
  }
  Artifact[] public artifacts;
  mapping(uint256 => uint256[]) public getTokenIDsByArtifactID;
  mapping(uint256 => uint256) public getArtifactIDByTokenID;

  // Artifact Metadata Mapping
  mapping(string => bool) public artifactMetadataExists;
  mapping(string => uint256) public getArtifactIDByMetadata;

  // Store Royalty Permyriad for Artifacts
  mapping(uint256 => uint256) public getRoyaltyPermyriadByArtifactID;

  // Artifact Fork Data
  mapping(uint256 => uint256[]) public getForksOfArtifact;
  mapping(uint256 => uint256) public getArtifactForkedFrom;

  // Mentions (for on-chain tagging)
  mapping(uint256 => address[]) public getMentionsByArtifactID;
  mapping(address => uint256[]) public getArtifactsMentionedInByAddress;

  // Used to Split Royalty
  // See EIP-2981 for more information: https://eips.ethereum.org/EIPS/eip-2981
  struct RoyaltyInfo {
    address reciever;
    uint256 percent;
  }
  mapping(uint256 => RoyaltyInfo) getRoyaltyInfoByTokenId;
  mapping(uint256 => RoyaltyInfo) getRoyaltyInfoByArtifactId;

  /// @notice returns royalties info for the given Artifact ID
  /// @dev can be used by other contracts to get royaltyInfo
  /// @param _tokenID Artifact ID of which royaltyInfo is to be fetched
  /// @param _salePrice Desired Sale Price of the token to run calculations on
  function royaltyInfo(uint256 _tokenID, uint256 _salePrice)
  	external
  	view
  	returns (address receiver, uint256 royaltyAmount)
  {
    RoyaltyInfo memory rInfo = getRoyaltyInfoByArtifactId[_tokenID];
	if (rInfo.reciever == address(0)) return (address(0), 0);
	uint256 amount = (_salePrice * rInfo.percent) / 10000;
	return (payable(rInfo.reciever), amount);
  }




  // Monument Permission Management

  /// @notice Adds Editor to the Monument
  /// @dev Sets `isEditorOfMonumentID` to true.
  /// @param _editor Address that the Founder wishes to make the Editor.
  /// @param _monumentID Monument ID of the Monument to add the Editor to.
  function addEditorToMonument(address _editor, uint256 _monumentID) 
    external
    returns(address) 
  {
    permissionManagement.adhereToBanMethod(msg.sender);
    require(
      monuments[_monumentID].founder == msg.sender || 
      permissionManagement.moderators(msg.sender) == true, 
      "Unauthorized call to Add Editor"
    );
    
    getMonumentIDsByEditor[_editor].push(_monumentID);
    getEditorsByMonumentID[_monumentID].push(_editor);
    isEditorOfMonumentID[msg.sender][_monumentID] = true;

    emit MonumentPermissionsModified (
      msg.sender, 
      _editor, 
      MonumentPermissionChange.PROMOTED_TO_EDITOR
    );
    
    return _editor;
  }

  /// @notice Removes Editor from the Monument
  /// @dev Sets `isEditorOfMonumentID` to false.
  /// @param _editor Address that the Founder wishes to not make the Editor.
  /// @param _monumentID Monument ID of the Monument to remove the Editor from.
  function removeEditorFromMonument(address _editor, uint256 _monumentID) 
    external
    returns(address) 
  {
    permissionManagement.adhereToBanMethod(msg.sender);
    require(
      monuments[_monumentID].founder == msg.sender || 
      permissionManagement.moderators(msg.sender) == true, 
      "Unauthorized call to Remove Editor"
    );
    isEditorOfMonumentID[msg.sender][_monumentID] = false;
    emit MonumentPermissionsModified (
      msg.sender, 
      _editor, 
      MonumentPermissionChange.KICKED_FROM_TEAM
    );
    return _editor;
  }

  /// @notice To change the Founder of a Monument
  /// @dev Does "monuments[_monumentID].founder = _newFounder;"
  /// @param _monumentID Monument ID of the Monument to change the Founder of.
  /// @param _newFounder Address that the current Founder wishes to make the new Founder.
  function transferFoundership(uint256 _monumentID, address _newFounder) 
    external
    returns(address)
  {
    permissionManagement.adhereToBanMethod(msg.sender);
    require(
      monuments[_monumentID].founder == msg.sender || 
      permissionManagement.moderators(msg.sender) == true, 
      "Unauthorized call to Change Founder"
    );
    monuments[_monumentID].founder = _newFounder;
    emit MonumentPermissionsModified (
      msg.sender, 
      _newFounder, 
      MonumentPermissionChange.MADE_FOUNDER
    );
    return _newFounder;
  }





  // Events
  event BuildMonument (
    uint256 indexed id,
    string indexed metadata,
    address indexed founder,
    uint256 paidAmount
  );
  event MintArtifact (
    uint256 indexed id,
    uint256 indexed monumentId,
    string metadata,
    uint256 supply,
    address indexed author,
    uint256 paidAmount
  );
  event MonumentPermissionsModified (
    address actionedBy, 
    address _address, 
    MonumentPermissionChange _roleChange
  );





  // Enums
  enum MonumentPermissionChange { 
    MADE_FOUNDER,
    PROMOTED_TO_EDITOR,
    KICKED_FROM_TEAM
  }



  // Public Functions

  /// @notice Creates a Monument
  /// @param metadata IPFS / Arweave / Custom URL
  /// @param forkOf Monument ID of the Monument you want to create a Fork of. 0 for nothing.
  function buildMonument(
      string memory metadata,
      string memory artifactMetadata,
      uint256 forkOf
    )
    external
    payable
    nonReentrant
    returns(uint256)
  {
    permissionManagement.adhereToBanMethod(msg.sender);

    // metadata must not be empty
    require(bytes(metadata).length > 0 || bytes(artifactMetadata).length > 0, "Empty Metadata");

    // make sure another monument with the same metadata does not exist
    require(monumentMetadataExists[metadata] != true, "Monument already minted");

    // forkOf must be a valid Monument ID
    require(monuments[forkOf].timestamp > 0, "Invalid forkOf Monument");

    // charge taxes (if any)
    _chargeMonumentTax();

    uint256 monumentID = _buildMonument(metadata);

    // Attach Forks
    getForksOfMonument[forkOf].push(monumentID);
    getMonumentForkedFrom[monumentID] = forkOf;

    // Make a Genesis Artifact just for the Monument
    _mintArtifact(0, artifactMetadata, 1);

    return monumentID;
  }

  /// @notice Creates an Artifact on a Monument
  /// @param monumentId Monument ID of the Monument to mint this Artifact on.
  /// @param metadata IPFS / Arweave / Custom URL
  /// @param supply A non-zero value of NFTs to mint for this Artifact
  /// @param mentions Array of addresses to Mention in the Artifact
  /// @param forkOf Artifact ID of the Artifact you want to create a Fork of. 0 for nothing.
  /// @param royaltyPermyriad Permyriad of Royalty tagged people wish to collectively collect on NFT sale in the market
  /// @param splitBeneficiaries An array of Beneficiaries to Split Royalties among
  /// @param permyriadsCorrespondingToSplitBeneficiaries An array specifying how much portion of the total royalty each split beneficiary gets
  function mintArtifact(
      uint256 monumentId,
      string memory metadata,
      uint256 supply,
      address[] memory mentions,
      uint256 forkOf,
      uint256 royaltyPermyriad,
      address[] memory splitBeneficiaries,
      uint256[] memory permyriadsCorrespondingToSplitBeneficiaries
    )
    external
    payable
    nonReentrant
    returns(uint256)
  {
    permissionManagement.adhereToBanMethod(msg.sender);
    
    // royaltyPermyriad should be 0-10000 only
    require(royaltyPermyriad >= 0 && royaltyPermyriad <= 10000, "Invalid Royalty Permyriad value");

    // splitBeneficiaries & permyriadsCorrespondingToSplitBeneficiaries Array length should be equal
    require(splitBeneficiaries.length == permyriadsCorrespondingToSplitBeneficiaries.length, "Invalid Beneficiary Data");

    // sum of permyriadsCorrespondingToSplitBeneficiaries must be 10k
    uint256 _totalPermyriad;
    for (uint256 i = 0; i < splitBeneficiaries.length; i++) {
      require(splitBeneficiaries[i] != address(0));
      require(permyriadsCorrespondingToSplitBeneficiaries[i] > 0);
      require(permyriadsCorrespondingToSplitBeneficiaries[i] <= 10000);
      _totalPermyriad += permyriadsCorrespondingToSplitBeneficiaries[i];
    }
    require(_totalPermyriad == 10000, "Total Permyriad must be 10000");

    // metadata must not be empty
    require(bytes(metadata).length > 0, "Empty Metadata");
    
    // must be a editor of the monument to be able to mint
    require(isEditorOfMonumentID[msg.sender][monumentId] == true, "You cant mint on this Monument");

    // make sure another artifact with the same metadata does not exist
    require(artifactMetadataExists[metadata] != true, "Artifact already minted");

    // forkOf must be a valid Artifact ID
    require(artifacts[forkOf].timestamp > 0, "Invalid forkOf Artifact");

    // supply cant be 0
    require(supply > 0, "Supply must be non-zero");

    // charge taxes (if any)
    _chargeArtifactTax();

	uint256 artifactID = _mintArtifact(monumentId, metadata, supply);
	getRoyaltyPermyriadByArtifactID[artifactID] = royaltyPermyriad;

    // Mint a new Splits contract
    Splits splits = new Splits(splitBeneficiaries, permyriadsCorrespondingToSplitBeneficiaries);

    // Populate royalties map for new Artifact ID
    getRoyaltyInfoByArtifactId[artifactID] = RoyaltyInfo(address(splits), royaltyPermyriad);

    // Mention
    getMentionsByArtifactID[artifactID] = mentions;
    for (uint256 i = 0; i < mentions.length; i++) {
      getArtifactsMentionedInByAddress[mentions[i]].push(artifactID);
    }

    // Attach Forks
    getForksOfArtifact[forkOf].push(artifactID);
    getArtifactForkedFrom[artifactID] = forkOf;

    return artifactID;
  }




  // Functions for Internal Use

  /// @dev Builds a Monument with no checks. For internal use only.
  function _buildMonument(
      string memory metadata
    )
    internal
    returns(uint256)
  {
    uint256 newId = _monumentIDs.current();
    _monumentIDs.increment();

    monuments.push(
      Monument(
        newId,
        metadata,
        block.timestamp,
        msg.sender
      )
    );
    monumentMetadataExists[metadata] = true;
    getMonumentIDByMetadata[metadata] = newId;

    // Set Permissions
    getMonumentIDsByFounder[msg.sender].push(newId);
    getMonumentIDsByEditor[msg.sender].push(newId);
    getEditorsByMonumentID[newId].push(msg.sender);
    isEditorOfMonumentID[msg.sender][newId] = true;

    // Emit Event
    emit BuildMonument (
      newId,
      metadata,
      msg.sender,
      msg.value
    );

    return newId;
  }

  /// @dev Builds an Artifact with no checks. For internal use only.
  function _mintArtifact(
      uint256 monumentId,
      string memory metadata,
      uint256 supply
    )
    internal
    returns(uint256)
  {
    uint256 newId = _artifactIDs.current();
    _artifactIDs.increment();

    artifacts.push(
      Artifact(
        newId,
        monumentId,
        metadata,
        supply,
        block.timestamp,
        msg.sender
      )
    );
    artifactMetadataExists[metadata] = true;
    getArtifactIDByMetadata[metadata] = newId;
    getArtifactIDsByMonumentID[monumentId].push(newId);

    // Mint tokens
    for (uint256 i = 0; i < supply; i++) {
      uint256 newTokenId = _tokenIDs.current();
      _tokenIDs.increment();

      _mint(msg.sender, newTokenId);
      _setTokenURI(newTokenId, metadata);
      
      getTokenIDsByMonumentID[monumentId].push(newTokenId);
      getTokenIDsByArtifactID[newId].push(newTokenId);
      getArtifactIDByTokenID[newTokenId] = newId;
    }

    // Emit Event
    emit MintArtifact (
      newId,
      monumentId,
      metadata,
      supply,
      msg.sender,
      msg.value
    );

    return newId;
  }
}