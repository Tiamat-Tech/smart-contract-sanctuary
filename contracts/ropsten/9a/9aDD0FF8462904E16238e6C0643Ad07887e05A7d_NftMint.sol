// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

error InvalidInput(string message);

contract NftMint is ERC721URIStorageUpgradeable {

    event NewNFT(uint id, address owner);

    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    function initialize(string memory tokenName, string memory symbol) public initializer {
        __ERC721_init(tokenName, symbol);
    }

    /// @param owner of the NFT, URI of the minted NFT metadata
    /// @return minted token id
    function mintToken(address owner, string memory metadataURI) public returns (uint256) {
        require(bytes(metadataURI).length > 0, "NFT metadataURI must not be empty.");
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(owner, id);
        _setTokenURI(id, metadataURI);

        emit NewNFT(id, msg.sender);
        return id;
    }
}