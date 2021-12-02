// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Media is
    ERC721,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable,
    ReentrancyGuard,
    ERC721Enumerable
{
    struct Metadata {
        string name;
        uint256 tokenId;
        uint256 serialNumber;
        string authorName;
        string authorLink;
        address firstOwner;
        string appraisalText;
        string mainPhoto;
        string certificateImage;
        string[] photos;
        string video;
    }

    mapping(uint256 => Metadata) private metadatas;

    constructor() ERC721("Media", "MEDIA") {}

    /**
     * @notice Require that the token has not been burned and has been minted
     */
    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Media: nonexistent token");
        _;
    }

    /**
     * @notice Ensure that the provided spender is the approved or the owner of
     * the media for the specified tokenId
     */
    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Media: Only approved or owner"
        );
        _;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenIdsByOwner(address account)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = ERC721.balanceOf(account);

        uint256[] memory tokenIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = ERC721Enumerable.tokenOfOwnerByIndex(account, i);
            tokenIds[i] = tokenId;
        }
        return tokenIds;
    }

    function mintToken(address user, Metadata memory metadata)
        public
        returns (uint256)
    {
        require(
            (user == _msgSender() || _msgSender() == owner()),
            "Media: caller should be the owner"
        );
        require(user == metadata.firstOwner, "Media: invalid owner");
        uint256 tokenId = ERC721Enumerable.totalSupply() + 1;
        _safeMint(user, tokenId);
        metadata.tokenId = tokenId;
        metadatas[tokenId] = metadata;
        return tokenId;
    }

    function getPhotos(uint256 tokenId) external returns(string[] memory) {
        return metadatas[tokenId].photos;
    }
}