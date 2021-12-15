// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./ERC721Tradable.sol";

/**
 * @title Asset
 * Asset - a contract for Seek's generic non-fungible assets.
 */
contract Asset is ERC721Tradable, EIP712 {
    mapping (uint256 => string) private _tokenURIs;
    string private constant SIGNING_DOMAIN = "SeekNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";

    string private _baseTokenURI = "https://api.staging.seekxr.com/v1/nft/contracts/2/tokens/";

    constructor(address _proxyRegistryAddress)
        ERC721Tradable("Asset", "SXR", _proxyRegistryAddress)
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {}

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function ownerSetTokenURI(uint256 tokenId, string memory _tokenURI) external onlyOwner() {
        _setTokenURI(tokenId, _tokenURI);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    function _setBaseTokenURI(string memory baseContractURI) external onlyOwner() {
        _baseTokenURI = baseContractURI;
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }

        return string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId), "/"));
    }

    struct NFTVoucher {
        /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
        uint256 tokenId;

        /// @notice The metadata URI to associate with this token.
        string uri;

        /// @notice the EIP-712 signature of all other fields in the NFTVoucher struct. For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
        bytes signature;
    }

    /// @notice Redeems an NFTVoucher for an actual NFT, creating it in the process.
    /// @param redeemer The address of the account which will receive the NFT upon success.
    /// @param voucher A signed NFTVoucher that describes the NFT to be redeemed.
    function redeem(address redeemer, NFTVoucher calldata voucher) public payable returns (uint256) {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher);

        // make sure that the signer is the owner
        require(signer == owner(), "Signature invalid");

        // first assign the token to the signer, to establish provenance on-chain
        _safeMint(signer, voucher.tokenId);

        // set the token uri if provided
        if (bytes(voucher.uri).length > 0) {
            _setTokenURI(voucher.tokenId, voucher.uri);
        }

        // transfer the token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);

        return voucher.tokenId;
    }

    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An NFTVoucher describing an unminted NFT.
    function _verify(NFTVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(_hashTypedDataV4(keccak256(abi.encode(
        keccak256("NFTVoucher(uint256 tokenId,string uri)"),
        voucher.tokenId,
        keccak256(bytes(voucher.uri))
        ))));
    }
}