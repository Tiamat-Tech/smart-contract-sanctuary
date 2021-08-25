// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC1155Tradable.sol";

/**
 * @title HDV
 * HDV - a contract for The House of da Vinci tokens.
 */
contract HDV is ERC1155Tradable {
    string private contractMetadataURI;

    constructor(
        string memory _contractMetadataURI,
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _proxyRegistryAddress
    ) ERC1155Tradable(_name, _symbol, _uri, _proxyRegistryAddress) {
        contractMetadataURI = _contractMetadataURI;
    }

    // https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public view returns (string memory) {
        return contractMetadataURI;
    }

    function setContractURI(string memory _contractMetadataURI)
        external
        onlyOwner
    {
        contractMetadataURI = _contractMetadataURI;
    }
}