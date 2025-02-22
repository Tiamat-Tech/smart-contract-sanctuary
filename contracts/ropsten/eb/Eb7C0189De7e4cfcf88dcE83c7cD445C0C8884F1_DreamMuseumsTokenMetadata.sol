// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./dream-museums-token.sol";
import "./erc721-metadata.sol";
import "./strings.sol";

/**
 * @dev Optional metadata implementation for ERC-721 non-fungible token standard.
 */
contract DreamMuseumsTokenMetadata is DreamMuseumsToken, ERC721Metadata {
    /**
     * @dev A descriptive name for a collection of NFTs.
     */
    string internal nftName = "Dream Museums";

    /**
     * @dev An abbreviated name for DreamMuseumsTokens.
     */
    string internal nftSymbol = "DREAM";

    /**
     * @dev Mapping from NFT ID to metadata uri.
     */
    mapping(uint256 => string) internal idToUri;

    /**
     * @notice When implementing this contract don't forget to set nftName and nftSymbol.
     * @dev Contract constructor.
     */
    constructor() {
        supportedInterfaces[0x5b5e139f] = true; // ERC721Metadata
    }

    /**
     * @dev Returns a descriptive name for a collection of DreamMuseumsTokens.
     * @return _name Representing name.
     */
    function name() external view override returns (string memory _name) {
        _name = nftName;
    }

    /**
     * @dev Returns an abbreviated name for DreamMuseumsTokens.
     * @return _symbol Representing symbol.
     */
    function symbol() external view override returns (string memory _symbol) {
        _symbol = nftSymbol;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(bytes(idToUri[_tokenId]).length > 0, NOT_VALID_NFT);
        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
    }

    /**
     * @notice This is an internal function that can be overriden if you want to implement a different
     * way to generate token URI.
     * @param _tokenId Id for which we want uri.
     * @return URI of _tokenId.
     */
    function _tokenURI(uint256 _tokenId)
        internal
        view
        virtual
        returns (string memory)
    {
        return idToUri[_tokenId];
    }

    /**
     * @notice This is an internal function which should be called from user-implemented external
     * burn function. Its purpose is to show and properly initialize data structures when using this
     * implementation. Also, note that this burn implementation allows the minter to re-mint a burned
     * NFT.
     * @dev Burns a NFT.
     * @param _tokenId ID of the NFT to be burned.
     */
    function _burn(uint256 _tokenId) internal virtual override {
        super._burn(_tokenId);

        delete idToUri[_tokenId];
    }

    /**
     * @notice This is an internal function which should be called from user-implemented external
     * function. Its purpose is to show and properly initialize data structures when using this
     * implementation.
     * @dev Set a distinct URI (RFC 3986) for a given NFT ID.
     * @param _tokenId Id for which we want URI.
     * @param _uri String representing RFC 3986 URI.
     */
    function _setTokenUri(uint256 _tokenId, string memory _uri)
        internal
        validDreamMuseumsToken(_tokenId)
    {
        idToUri[_tokenId] = _uri;
    }
}