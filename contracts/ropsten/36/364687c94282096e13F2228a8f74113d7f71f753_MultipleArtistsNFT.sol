// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "./../libraries/Administrated.sol";
import "./../marketplace/ISplitterContract.sol";

/// @dev we will bring in the openzeppelin ERC721 NFT functionality
contract MultipleArtistsNFT is
    ERC721Royalty,
    ERC721URIStorage,
    ERC721Enumerable,
    Administrated
{
    /**
     * @notice Runs once when the contract is deployed
     * @param _name - NFT token name
     * @param _symbol - NFT token symbol
     * @param _admin - address of the admin
     * @param _splitter - address of the Splitter contract
     * @param _artist - Arrdess of artist
     * @param _primaryDistRecipients - List of primary addresses for distribution
     * @param _primaryDistShares - List of primary percentages for distribution
     * @param _secondaryDistRecipients - List of secondary addresses for distribution
     * @param _secondaryDistShares - List of secondary percentages for distribution
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _admin,
        address _splitter,
        address _artist,
        address[] memory _primaryDistRecipients,
        uint256[] memory _primaryDistShares,
        address[] memory _secondaryDistRecipients,
        uint256[] memory _secondaryDistShares
    ) ERC721(_name, _symbol) {
        require(_admin != address(0), "zero_addr");
        require(_splitter != address(0), "zero_addr");
        require(_artist != address(0), "zero_addr");
        require(
            _primaryDistRecipients.length == _primaryDistShares.length,
            "diff_length"
        );
        require(
            _secondaryDistRecipients.length == _secondaryDistShares.length,
            "diff_length"
        );
        changeAdmin(_admin);
        ISplitterContract(_splitter).setPrimaryDistribution(
            _artist,
            _primaryDistRecipients,
            _primaryDistShares
        );
        ISplitterContract(_splitter).setSecondaryDistribution(
            _artist,
            _secondaryDistRecipients,
            _secondaryDistShares
        );
    }

    /**
     * @notice Mint single token
     * @param _tokenURI - Full URI for token
     * @return _tokenId with created item ID
     */
    function mint(string memory _tokenURI)
        public
        onlyAdmin
        returns (uint256 _tokenId)
    {
        // Avoiding zero tokenId
        _tokenId = totalSupply() + 1;
        _mint(msg.sender, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
    }

    /**
     * @notice Mint multiple tokens
     * @param _tokenURIs - Array of token URIs
     * @return ids - array of token IDs
     */
    function mintBatches(string[] memory _tokenURIs)
        external
        onlyAdmin
        returns (uint256[] memory ids)
    {
        ids = new uint256[](_tokenURIs.length);
        for (uint64 i = 0; i < _tokenURIs.length; i++) {
            uint256 _id = mint(_tokenURIs[i]);
            ids[i] = _id;
        }
    }

    /**
     * @notice Get list of owner tokens
     * @param owner - Address to check
     * @return Array of token IDs
     */
    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(owner);
        if (count == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory ids = new uint256[](count);
            uint256 i;
            for (i = 0; i < count; i++) {
                ids[i] = tokenOfOwnerByIndex(owner, i);
            }
            return ids;
        }
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator)
        external
        onlyAdmin
    {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `tokenId` must be already minted.
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyAdmin {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function resetTokenRoyalty(uint256 tokenId) external onlyAdmin {
        _resetTokenRoyalty(tokenId);
    }

    /// @notice _beforeTokenTransfer override
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /// @notice _burn override
    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721, ERC721URIStorage, ERC721Royalty)
    {
        super._burn(tokenId);
    }

    /// @notice supportsInterface override
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice tokenURI override
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}