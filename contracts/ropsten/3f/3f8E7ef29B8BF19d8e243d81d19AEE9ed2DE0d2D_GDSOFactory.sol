// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./AbstractAccessControl.sol";
import "../interfaces/GDSO.sol";

import "hardhat/console.sol";

contract GDSOFactory is
    ERC721URIStorage,
    ERC721Enumerable,
    AbstractAccessControl,
    Pausable
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    uint256 private _lockingPeriod = 60 days;
    uint256 private _maxSupply;
    GDSO[] private _gdsos;

    // maps tokenId to locked time
    mapping(uint256 => uint256) private _lockTime;

    // events
    event NewGDSO(address creator, uint256 tokenId, string tokenURI);
    event URIUpdated(uint256 tokenId, string tokenURI);

    constructor(uint256 maxSupply) ERC721("Genesis DSO", "GDSO") {
        // sets max supply
        _maxSupply = maxSupply;
        // Grants creator role to owner.
        grantCreatorRole(msg.sender);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
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

    /**
     * @dev This function needs to be overriden as it's declared in ERC721 and AccessControl.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function createGDSO(
        uint32 row,
        uint32 column,
        string memory _tokenURI
    ) public onlyCreator {
        require(_maxSupply > _tokenIds.current(), "GDSO: max supply reached.");
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _gdsos.push(GDSO(newItemId, row, column));
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        emit NewGDSO(msg.sender, newItemId, _tokenURI);
    }

    // TODO: consider reusing this function with DSOFactory as well
    // may be create a new contract "AbstractNFTFactory"
    function updateURI(uint256 tokenId, string memory _tokenURI)
        public
        onlyCreator
    {
        _setTokenURI(tokenId, _tokenURI);
        emit URIUpdated(tokenId, _tokenURI);
    }

    // WIP
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721) {
        console.log("lockTime of token %s is %s", tokenId, _lockTime[tokenId]);

        // require(
        //     _lockTime[tokenId] <= block.timestamp,
        //     "GDSOFactory: Unable to transfer. Locking period is still running."
        // );
        // console.log("transferFrom", from, to, tokenId);

        _lockTime[tokenId] = block.timestamp + _lockingPeriod;
        super.safeTransferFrom(from, to, tokenId);
    }

    // TODO: add tests
    function getGDSOsByOwner(address owner)
        external
        view
        returns (GDSO[] memory)
    {
        GDSO[] memory result = new GDSO[](ERC721.balanceOf(owner));
        uint256 counter = 0;
        for (uint256 i = 0; i < _gdsos.length; i++) {
            if (ERC721.ownerOf(_gdsos[i].id) == owner) {
                result[counter] = _gdsos[i];
                counter++;
            }
        }
        return result;
    }

    // TODO: add tests
    function getAllGDSOs() external view returns (GDSO[] memory) {
        return _gdsos;
    }

    // TODO: add tests
    function getGDSOById(uint256 dsoId) external view returns (GDSO memory) {
        GDSO memory result;
        for (uint256 i = 0; i < _gdsos.length; i++) {
            if (_gdsos[i].id == dsoId) {
                result = _gdsos[i];
                break;
            }
        }
        return result;
    }
}