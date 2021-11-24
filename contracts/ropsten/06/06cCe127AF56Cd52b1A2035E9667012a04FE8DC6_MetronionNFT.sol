//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IMetronionNFT.sol";

contract MetronionNFT is ERC721, ERC721Enumerable, Ownable, IMetronionNFT {
    Version[] private versions;
    Metronion[] private _metronions;
    string private _uri;

    address public override originalMinter;
    uint256 public constant CAP_PER_MINT = 50;  // limit amount can be minted per tx to avoid gas limit reached

    constructor(
        string memory baseURI,
        uint256 maxSupply,
        string memory provenance
    ) ERC721("MetronionNFT", "METRONION") {
        _uri = baseURI;
        versions.push(Version(0, 0, maxSupply, provenance));
    }

    /**
     * @dev Throw error if not called by Original Minter
     */
    modifier onlyOriginalMinter() {
        require(originalMinter == msg.sender, "MetronionNFT: caller is not original minter");
        _;
    }

    /**
     * @dev Set Orignal Minter to new address
     * Can only called by owner of this contract
     * @param minter new Original Minter
     */
    function setOriginalMinter(address minter) external onlyOwner {
        originalMinter = minter;
    }

    /**
     * @dev Set NFT base URI
     * Can only called by owner of this contract
     * @param baseURI new base URI
     */
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _uri = baseURI;
        emit UpdateBaseURI(baseURI);
    }

    /**
     * @dev Call this function to mint Metronion
     * Can only called by Original Minter
     */
    function mintMetronion(
        uint256 versionId,
        uint256 amount,
        address to
    ) external override onlyOriginalMinter {
        Version storage version = versions[versionId];

        require(amount > 0, "MetronionNFT: amount out of range");
        require(amount <= CAP_PER_MINT, "MetronionNFT: amount exceed CAP_PER_MINT");
        require(
            version.currentSupply + amount <= version.maxSupply,
            "MetronionNFT: amount of Metronions left is not enough"
        );

        version.currentSupply += amount;

        for (uint256 i = 0; i < amount; i++) {
            uint256 metronionId = _createMetronion();
            emit MetronionCreated(metronionId, versionId, to);
            _safeMint(to, metronionId);
        }
    }

    /**
     * @dev add new version of Metronion
     * Can only call be owner of this contract
     */
    function addNewVersion(uint256 maxSupply, string memory provenance) external onlyOwner {
        uint256 latestVersionId = getLatestVersion();
        Version memory latestVersion = versions[latestVersionId];

        require(
            latestVersion.currentSupply == latestVersion.maxSupply,
            "MetronionNFT: latest version mint is not finished"
        );

        versions.push(Version(0, 0, maxSupply, provenance));

        emit NewVersionAdded(latestVersionId + 1);
    }

    /**
     * @dev Call only by owner to finalized starting index
     * @param versionId version ID should exist
     */
    function finalizeStartingIndex(uint256 versionId) external override onlyOwner {
        Version storage version = versions[versionId];

        require(version.startingIndex == 0, "MetronionNFT: starting index is already finalized");
        require(version.currentSupply == version.maxSupply, "MetronionNFT: there are still metronions left");

        uint256 startingIndex = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) %
            version.maxSupply;
        if (startingIndex == 0) startingIndex = startingIndex + 1;
        version.startingIndex = startingIndex;

        emit StartingIndexFinalized(versionId, startingIndex);
    }

    /**
     * @dev return latest version of Metronion
     */
    function getLatestVersion() public view returns (uint256) {
        return versions.length - 1;
    }

    /**
     * @dev return version config for specific versionId
     * @param versionId version id
     */
    function versionById(uint256 versionId) external view returns (Version memory version) {
        return versions[versionId];
    }

    /**
     * @dev return total supply for Metronion with specific version ID
     */
    function totalSupplyWithVersionId(uint256 versionId) external view returns (uint256) {
        Version storage version = versions[versionId];
        return version.currentSupply;
    }

    /**
     * @dev create Metronion and return latest metronion ID
     */
    function _createMetronion() private returns (uint256 metronionId) {
        uint256 latestVersion = versions.length - 1;
        _metronions.push(Metronion("", latestVersion));
        metronionId = _metronions.length - 1;
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        return super._beforeTokenTransfer(from, to, tokenId);
    }
}