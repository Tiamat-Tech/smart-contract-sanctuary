// SPDX-License-Identifier: GPL-3.0

/// @title The DAOISM ERC-721

pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ERC721Checkpointable } from "./ERC721Checkpointable.sol";
import { ERC721 } from "./ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IProxyRegistry } from "./IProxyRegistry.sol";

contract GovToken is IERC721, ERC721Checkpointable, Ownable  {
    event DAOUpdated(address DAO);
    event TokenBurned(uint tokenId);
    event TokenCreated(uint tokenId);

    // The DAO address (creators org)
    address public DAO;

    // The internal token ID tracker
    uint256 private _currentTokenId;

    // IPFS content hash of contract-level metadata
    string private _contractURIHash = "QmZi1n79FqWt2tTLwCqiy6nLM6xLGRsEPQ5JmReJQKNNzX";

    // OpenSea"s Proxy Registry
    IProxyRegistry public immutable proxyRegistry;

    /**
     * @notice Require that the sender is the DAO.
     */
    modifier onlyDAO() {
        require(msg.sender == DAO, "Sender is not the DAO");
        _;
    }

    constructor(
        address _DAO,
        IProxyRegistry _proxyRegistry
    ) ERC721("Govs", "GOVNA") {
        DAO = _DAO;
        proxyRegistry = _proxyRegistry;
    }

    /**
     * @notice The IPFS URI of contract-level metadata.
     */
    function contractURI() public view returns (string memory) {
        return string(abi.encodePacked("ipfs://", _contractURIHash));
    }

    /**
     * @notice Set the _contractURIHash.
     * @dev Only callable by the owner.
     */
    function setContractURIHash(string memory newContractURIHash) external onlyOwner {
        _contractURIHash = newContractURIHash;
    }

    /**
     * @notice Override isApprovedForAll to whitelist user"s OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    function mint() public returns (uint256) {
        return _mintTo(msg.sender, _currentTokenId++);
    }

    /**
     * @notice Burn a token.
     */
    function burn(uint256 tokenId) public onlyDAO {
        _burn(tokenId);
        emit TokenBurned(tokenId);
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "GovToken: URI query for nonexistent token");
        return "";
    }

    /**
     * @notice Set the DAO.
     * @dev Only callable by the DAO when not locked.
     */
    function setDAO(address _DAO) external onlyDAO {
        DAO = _DAO;

        emit DAOUpdated(_DAO);
    }

    /**
     * @notice Mint a Token with `tokenId` to the provided `to` address.
     */
    function _mintTo(address to, uint256 tokenId) internal returns (uint256) {
        _mint(owner(), to, tokenId);

        emit TokenCreated(tokenId);

        return tokenId;
    }
}