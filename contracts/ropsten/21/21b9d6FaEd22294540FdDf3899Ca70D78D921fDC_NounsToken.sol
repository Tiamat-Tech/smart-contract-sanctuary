// SPDX-License-Identifier: GPL-3.0

/// @title The Nouns ERC-721 token

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.6;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Checkpointable} from "./ERC721Checkpointable.sol";
// import { INounsDescriptor } from './interfaces/INounsDescriptor.sol';
// import { INounsSeeder } from './interfaces/INounsSeeder.sol';
import {INounsToken} from "./INounsToken.sol";
import {ERC721} from "./ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//import { IProxyRegistry } from './external/opensea/IProxyRegistry.sol';

contract NounsToken is INounsToken, Ownable, ERC721Checkpointable {
    // The nounders DAO address (creators org)
    address public noundersDAO;

    // An address who has permissions to mint Nouns
    address public minter;

    // Whether the minter can be updated
    bool public isMinterLocked;

    // The internal noun ID tracker
    uint256 private _currentNounId;

    // IPFS content hash of contract-level metadata
    string private _contractURIHash =
        "QmZi1n79FqWt2tTLwCqiy6nLM6xLGRsEPQ5JmReJQKNNzX";

    /**
     * @notice Require that the minter has not been locked.
     */
    modifier whenMinterNotLocked() {
        require(!isMinterLocked, "Minter is locked");
        _;
    }

    /**
     * @notice Require that the sender is the nounders DAO.
     */
    modifier onlyNoundersDAO() {
        require(msg.sender == noundersDAO, "Sender is not the nounders DAO");
        _;
    }

    /**
     * @notice Require that the sender is the minter.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, "Sender is not the minter");
        _;
    }

    constructor(address _noundersDAO, address _minter) ERC721("Nouns", "NOUN") {
        noundersDAO = _noundersDAO;
        minter = _minter;
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
    function setContractURIHash(string memory newContractURIHash)
        external
        onlyOwner
    {
        _contractURIHash = newContractURIHash;
    }

    /**
     * @notice Mint a Noun to the minter, along with a possible nounders reward
     * Noun. Nounders reward Nouns are minted every 10 Nouns, starting at 0,
     * until 183 nounder Nouns have been minted (5 years w/ 24 hour auctions).
     * @dev Call _mintTo with the to address(es).
     */
    function mint() public override onlyMinter returns (uint256) {
        if (_currentNounId <= 1820 && _currentNounId % 10 == 0) {
            _mintTo(noundersDAO, _currentNounId++);
        }
        return _mintTo(minter, _currentNounId++);
    }

    /**
     * @notice Burn a noun.
     */
    function burn(uint256 nounId) public override onlyMinter {
        _burn(nounId);
        emit NounBurned(nounId);
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "NounsToken: URI query for nonexistent token"
        );
        //return descriptor.tokenURI(tokenId, seeds[tokenId]);
        return "tokenURI"; //TODO: fix
    }

    /**
     * @notice Similar to `tokenURI`, but always serves a base64 encoded data URI
     * with the JSON contents directly inlined.
     */
    function dataURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "NounsToken: URI query for nonexistent token"
        );
        //return descriptor.dataURI(tokenId, seeds[tokenId]);
        return "dataURI"; //TODO: fix
    }

    /**
     * @notice Set the nounders DAO.
     * @dev Only callable by the nounders DAO when not locked.
     */
    function setNoundersDAO(address _noundersDAO)
        external
        override
        onlyNoundersDAO
    {
        noundersDAO = _noundersDAO;

        emit NoundersDAOUpdated(_noundersDAO);
    }

    /**
     * @notice Set the token minter.
     * @dev Only callable by the owner when not locked.
     */
    function setMinter(address _minter)
        external
        override
        onlyOwner
        whenMinterNotLocked
    {
        minter = _minter;

        emit MinterUpdated(_minter);
    }

    /**
     * @notice Lock the minter.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockMinter() external override onlyOwner whenMinterNotLocked {
        isMinterLocked = true;

        emit MinterLocked();
    }

    /**
     * @notice Mint a Noun with `nounId` to the provided `to` address.
     */
    function _mintTo(address to, uint256 nounId) internal returns (uint256) {
        //  INounsSeeder.Seed memory seed = seeds[nounId] = seeder.generateSeed(nounId, descriptor);

        _mint(owner(), to, nounId);
        // emit NounCreated(nounId, seed);
        emit NounCreated(nounId);

        return nounId;
    }
}