// SPDX-License-Identifier: ISC
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/NFT.sol";
import "./utils/Taxes.sol";
import "./Splits.sol";

/// @title MonumentArtifacts Contract
/// @author [email protected]
/// @notice This contract shall be the prime Monument NFT contract consisting of all the Artifacts in the Metaverse.
contract MonumentArtifacts is NFT, Taxes, ReentrancyGuard {
  /// @notice Constructor function for the MonumentArtifacts Contract
  /// @dev Constructor function for the MonumentArtifacts ERC721 Contract
  /// @param name_ Name of the Monument artifact Collection
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
    // Build Genesis Artifact and Zero Token
    _mintArtifact("https://monument.app/artifacts/0.json", 1, 1, block.timestamp);
  }




  // token IDs counter
  using Counters for Counters.Counter;
  Counters.Counter public totalArtifacts;
  Counters.Counter public totalTokensMinted;




  // Artifacts
  struct Artifact {
    uint256 id;
    string metadata;
    uint256 totalSupply;
    uint256 initialSupply;
    uint256 currentSupply;
    uint256 blockTimestamp;
    uint256 artifactTimestamp;
    address author;
  }
  Artifact[] public artifacts;

  // Artifact Methods
  mapping(address => uint256[]) public getArtifactIDsByAuthor;

  function getArtifactAuthor(uint256 artifactId) public view virtual returns (address author) {
    return artifacts[artifactId].author;
  }

  function getArtifactSupply(uint256 artifactId) 
    public
    view
    virtual
    returns (
      uint256 totalSupply,
      uint256 currentSupply,
      uint256 initialSupply
    ) {
    return (
      artifacts[artifactId].totalSupply,
      artifacts[artifactId].currentSupply,
      artifacts[artifactId].initialSupply
    );
  }

  // Track Artifact Tokens
  mapping(uint256 => uint256[]) public getTokenIDsByArtifactID;
  mapping(uint256 => uint256) public getArtifactIDByTokenID;
  mapping(address => uint256[]) public getTokenIDsByAuthor;
  mapping(uint256 => address) public getAuthorByTokenID;

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
    uint256 percent; // it's actually a permyriad (parts per ten thousand)
  }
  mapping(uint256 => RoyaltyInfo) public getRoyaltyInfoByArtifactId;

  /// @notice returns royalties info for the given Artifact ID
  /// @dev can be used by other contracts to get royaltyInfo
  /// @param _tokenID Token ID of which royaltyInfo is to be fetched
  /// @param _salePrice Desired Sale Price of the token to run calculations on
  function royaltyInfo(uint256 _tokenID, uint256 _salePrice)
  	external
  	view
  	returns (address receiver, uint256 royaltyAmount)
  {
    RoyaltyInfo memory rInfo = getRoyaltyInfoByArtifactId[getArtifactIDByTokenID[_tokenID]];
	if (rInfo.reciever == address(0)) return (address(0), 0);
	uint256 amount = _salePrice * rInfo.percent / 10000;
	return (payable(rInfo.reciever), amount);
  }




  // Events
  event MintArtifact (
    uint256 indexed id,
    string metadata,
    uint256 totalSupply,
    uint256 initialSupply,
    address indexed author,
    uint256 paidAmount
  );




  // Public Functions

  /// @notice Creates an Artifact on a Monument
  /// @param metadata IPFS / Arweave / Custom URL
  /// @param totalSupply A non-zero value of NFTs to mint for this Artifact
  /// @param initialSupply Should pre-mint all the editions?
  /// @param mentions Array of addresses to Mention in the Artifact
  /// @param forkOf Artifact ID of the Artifact you want to create a Fork of. 0 for nothing.
  /// @param artifactTimestamp Date the Artifact corelates to.
  /// @param royaltyPermyriad Permyriad of Royalty tagged people wish to collectively collect on NFT sale in the market
  /// @param splitBeneficiaries An array of Beneficiaries to Split Royalties among
  /// @param permyriadsCorrespondingToSplitBeneficiaries An array specifying how much portion of the total royalty each split beneficiary gets
  /// @param splitsContractAddress If a Split Contract is already minted, specify its address, in that case, splitBeneficiaries & permyriadsCorrespondingToSplitBeneficiaries parameters shall be ignored
  function mintArtifact(
      string memory metadata,
      uint256 totalSupply,
      uint256 initialSupply,
      address[] memory mentions,
      uint256 forkOf,
      uint256 artifactTimestamp,
      uint256 royaltyPermyriad,
      address[] memory splitBeneficiaries,
      uint256[] memory permyriadsCorrespondingToSplitBeneficiaries,
      address splitsContractAddress
    )
    external
    payable
    nonReentrant
    returns (uint256 _artifactID)
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

    // make sure another artifact with the same metadata does not exist
    require(artifactMetadataExists[metadata] != true, "Artifact already minted");

    // forkOf must be a valid Artifact ID
    require(artifacts[forkOf].blockTimestamp > 0, "Invalid forkOf Artifact");

    // totalSupply cant be 0
    require(totalSupply > 0, "Supply must be non-zero");

    // initialSupply must be lesser than or equal to the totalSupply
    require(initialSupply <= totalSupply, "invalid initialSupply");

    // charge taxes (if any)
    _chargeArtifactTax();

	uint256 artifactID = _mintArtifact(metadata, totalSupply, initialSupply, artifactTimestamp);
	getRoyaltyPermyriadByArtifactID[artifactID] = royaltyPermyriad;

    if (royaltyPermyriad == 0) {
      getRoyaltyInfoByArtifactId[artifactID] = RoyaltyInfo(address(0), 0);
    } else if (splitsContractAddress != address(0)) {
      getRoyaltyInfoByArtifactId[artifactID] = RoyaltyInfo(splitsContractAddress, royaltyPermyriad);
    } else {
      // Mint a new Splits contract
      Splits splits = new Splits(splitBeneficiaries, permyriadsCorrespondingToSplitBeneficiaries);
      
      // Populate royalties map for new Artifact ID
      getRoyaltyInfoByArtifactId[artifactID] = RoyaltyInfo(address(splits), royaltyPermyriad);
    }

    // Mentions
    getMentionsByArtifactID[artifactID] = mentions;
    for (uint256 i = 0; i < mentions.length; i++) {
      getArtifactsMentionedInByAddress[mentions[i]].push(artifactID);
    }

    // Attach Forks
    getForksOfArtifact[forkOf].push(artifactID);
    getArtifactForkedFrom[artifactID] = forkOf;

    return artifactID;
  }


  /// @notice Mints editions of an Artifact
  /// @param artifactID ID of the Artifact whose editions to mint
  /// @param editions Number of editions to mint for the Artifact
  /// @param mintTo Specify the address where all the new minted tokens should go
  function mintEditions(
      uint256 artifactID,
      uint256 editions,
      address mintTo
    )
    external
    payable
    nonReentrant
    returns (
      uint256 _artifactID,
      uint256 _editions,
      address _mintedTo
    )
  {
    permissionManagement.adhereToBanMethod(msg.sender);

    // only moderators or artifact owners should be able to mint edtions.
    require(
        permissionManagement.moderators(msg.sender) ||
        artifacts[artifactID].author == msg.sender,
        "unauthorized call"
    );

    // only allow minting editions such that currentSupply shouldn't exceed totalSupply
    require(
        editions + artifacts[artifactID].currentSupply <= artifacts[artifactID].totalSupply, 
        "totalSupply exhausted"
    );

    // mint the edtions
    _mintTokens(artifactID, editions, mintTo);

    return (artifactID, editions, mintTo);
  }




  // Functions for Internal Use

  /// @dev Builds an Artifact with no checks. For internal use only.
  function _mintArtifact(
    string memory metadata,
    uint256 totalSupply,
    uint256 initialSupply,
    uint256 artifactTimestamp
  )
    internal
    returns (uint256 _artifactID)
  {
    uint256 newId = totalArtifacts.current();
    totalArtifacts.increment();

    artifacts.push(
      Artifact(
        newId,
        metadata,
        totalSupply,
        initialSupply,
        0, // current supply will be initially zero, it'll increase live as this function mints
        block.timestamp,
        artifactTimestamp,
        msg.sender
      )
    );
    artifactMetadataExists[metadata] = true;
    getArtifactIDByMetadata[metadata] = newId;
    getArtifactIDsByAuthor[msg.sender].push(newId);

    // Mint tokens
    _mintTokens(newId, initialSupply, msg.sender);

    // Emit Event
    emit MintArtifact (
      newId,
      metadata,
      totalSupply,
      initialSupply,
      msg.sender,
      msg.value
    );

    return newId;
  }


  /// @dev Mints multiple tokens with no checks. For internal use only.
  function _mintTokens(
    uint256 artifactID,
    uint256 amount,
    address mintTo
  )
    internal
    returns (
      uint256 _artifactID,
      uint256 _amount,
      address _mintedTo
    )
  {
    // Mint tokens
    for (uint256 i = 0; i < amount; i++) {
      uint256 newTokenId = totalTokensMinted.current();
      totalTokensMinted.increment();

      _mint(mintTo, newTokenId);
      _setTokenURI(newTokenId, artifacts[artifactID].metadata);
      
      getTokenIDsByArtifactID[artifactID].push(newTokenId);
      getArtifactIDByTokenID[newTokenId] = artifactID;

      getTokenIDsByAuthor[artifacts[artifactID].author].push(newTokenId);
      getAuthorByTokenID[newTokenId] = artifacts[artifactID].author;

      artifacts[artifactID].currentSupply = artifacts[artifactID].currentSupply + 1;
    }

    return (artifactID, amount, mintTo);
  }
}