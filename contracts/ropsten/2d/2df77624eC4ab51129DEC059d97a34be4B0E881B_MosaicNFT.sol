// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IMosaicNFT.sol";

contract MosaicNFT is IMosaicNFT, Ownable, ERC721URIStorage {

    struct NFtInfo {
        address originalNftAddress;
        uint256 originalNetworkId;
        uint256 nftId;
    }

    event NFTMinted(
        address indexed nftOwner,
        uint256 indexed nftId
    );

    event NFTMetadataSet(
        uint256 indexed nftId,
        string  nftUri,
        address originalNftAddress,
        uint256 originalNetworkID,
        uint256 originalNftId
    );

    uint256 private idTracker;

    address public minter;

    // mosaic nft ID => original nft info
    mapping(uint256 => NFtInfo) private nftInfoMapping;
    // hash of original nft info => nftId
    mapping(bytes32 => uint256) private mintedNftId;

    constructor(address _minter) ERC721("MosaicNFT", "mNFT") {
        minter = _minter;
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function mintNFT(
        address _to,
        string memory _tokenURI,
        address originalNftAddress,
        uint256 originalNetworkID,
        uint256 originalNftId
    ) external override {
        require(msg.sender == minter, "ONLY MINTER");

        idTracker = idTracker + 1;

        _safeMint(_to, idTracker);
        _setTokenURI(idTracker, _tokenURI);

        nftInfoMapping[idTracker] = NFtInfo(
            originalNftAddress,
            originalNetworkID,
            originalNftId
        );

        bytes32 id = _generateId(originalNftAddress, originalNetworkID, originalNftId);
        mintedNftId[id] = idTracker;

        emit NFTMinted(
            _to,
            idTracker
        );

        emit NFTMetadataSet(
            idTracker,
            _tokenURI,
            originalNftAddress,
            originalNetworkID,
            originalNftId
        );
    }


    function preMintNFT() external override returns (uint256) {
        require(msg.sender == minter, "ONLY MINTER");

        idTracker = idTracker + 1;

        _safeMint(minter, idTracker);

        emit NFTMinted(
            minter,
            idTracker
        );

        return idTracker;
    }

    function setNFTMetadata(
        uint256 nftId,
        string memory nftUri,
        address originalNftAddress,
        uint256 originalNetworkID,
        uint256 originalNftId
    ) external override {

        require(msg.sender == minter, "ONLY MINTER");
        require(ownerOf(nftId) == address(minter), "MINTER DOES NOT OWN");
        require(bytes(tokenURI(nftId)).length == 0, "METADATA ALREADY SET");

        _setTokenURI(nftId, nftUri);
        nftInfoMapping[nftId] = NFtInfo(
            originalNftAddress,
            originalNetworkID,
            originalNftId
        );

        emit NFTMetadataSet(
            nftId,
            nftUri,
            originalNftAddress,
            originalNetworkID,
            originalNftId
        );
    }

    function getNftId(
        address originalNftAddress,
        uint256 originalNetworkID,
        uint256 originalNftId
    ) external view override returns (uint256) {
        bytes32 id = _generateId(originalNftAddress, originalNetworkID, originalNftId);
        return mintedNftId[id];
    }

    function getOriginalNftInfo(uint256 nftId) external view override returns (address, uint256, uint256){
        NFtInfo memory nftInfo = nftInfoMapping[nftId];
        return (nftInfo.originalNftAddress, nftInfo.originalNetworkId, nftInfo.nftId);
    }

    function _generateId(
        address originalNftAddress,
        uint256 originalNetworkID,
        uint256 originalNftId
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(originalNetworkID, originalNftAddress, originalNftId));
    }

}