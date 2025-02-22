// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IArtworkStore.sol";
import "./base/TRLabOwnableUpgradeable.sol";
import "./lib/LibArtwork.sol";

/// @title Interface for artwork data storage
/// @author Joe
/// @notice This is the interface for TRLab NFTs artwork data storage.
/// @dev Separating artwork storage from the TRLabCore contract decouples features.
contract ArtworkStore is IArtworkStore, Initializable, TRLabOwnableUpgradeable, UUPSUpgradeable {
    mapping(uint256 => LibArtwork.Artwork) public artworks;
    uint256 public nextArtworkId;

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        nextArtworkId = 1;
    }

    /// @notice Creates a new digital artwork object in storage
    /// @inheritdoc IArtworkStore
    function createArtwork(
        address _creator,
        uint32 _totalSupply,
        string calldata _metadataPath,
        address _royaltyReceiver,
        uint256 _royaltyBps
    ) external override onlyOwnerOrTRLab returns (uint256) {
        require(_royaltyBps <= 10000, "Royalty bps should less than 10000");
        uint256 id = nextArtworkId++;
        artworks[id] = LibArtwork.Artwork({
            creator: _creator,
            printIndex: 0,
            totalSupply: _totalSupply,
            metadataPath: _metadataPath,
            royaltyReceiver: _royaltyReceiver,
            royaltyBps: _royaltyBps
        });
        emit ArtworkCreated(id, _creator, _royaltyReceiver, _royaltyBps, _totalSupply, _metadataPath);
        return id;
    }

    /// @notice Update Artwork Royalty Info, can only be called by owner at emergency
    /// @param  _artworkId id of the artwork
    /// @param  _royaltyReceiver address the royalty receiver
    /// @param  _royaltyBps uint256 the royalty percentage in bps
    function updateArtworkRoyaltyInfo(
        uint256 _artworkId,
        address _royaltyReceiver,
        uint256 _royaltyBps
    ) external override onlyOwner {
        require(_royaltyBps <= 10000, "Royalty bps should less than 10000");
        LibArtwork.Artwork storage art = artworks[_artworkId];
        art.royaltyReceiver = _royaltyReceiver;
        art.royaltyBps = _royaltyBps;
    }

    /// @notice Update Artwork metadata path (base uri), can only be called by owner at emergency
    /// @param  _artworkId id of the artwork
    /// @param  _metadataPath metadata path (base uri)
    function updateArtworkMetadataPath(uint256 _artworkId, string memory _metadataPath) external override onlyOwner {
        LibArtwork.Artwork storage art = artworks[_artworkId];
        art.metadataPath = _metadataPath;
    }

    /// @notice Increments the current print index of the artwork object, can be triggered by mint or burn.
    /// @inheritdoc IArtworkStore
    function incrementArtworkPrintIndex(uint256 _artworkId, uint32 _increment) external override onlyOwnerOrTRLab {
        LibArtwork.Artwork storage artwork = artworks[_artworkId];
        uint32 newPrintIndex = artwork.printIndex + _increment;
        require(newPrintIndex <= artwork.totalSupply, "increment exceeds artwork total supply!");
        artwork.printIndex = newPrintIndex;
        emit ArtworkPrintIndexIncrement(_artworkId, _increment, newPrintIndex);
    }

    /// Retrieves the artwork object by id
    /// @inheritdoc IArtworkStore
    function getArtwork(uint256 _artworkId) external view override returns (LibArtwork.Artwork memory artwork) {
        artwork = artworks[_artworkId];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}