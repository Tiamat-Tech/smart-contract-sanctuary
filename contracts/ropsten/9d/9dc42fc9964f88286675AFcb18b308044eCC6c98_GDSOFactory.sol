// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./AbstractAccessControl.sol";
import "../interfaces/GDSO.sol";

contract GDSOFactory is
    ERC721URIStorage,
    ERC721Enumerable,
    AbstractAccessControl,
    Pausable
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    uint256 private _maxSupply;
    mapping(uint256 => GDSO) private _idToGDSO;

    // events
    event NewGDSO(address creator, uint256 tokenId, string tokenURI);
    event URIUpdated(uint256 tokenId, string tokenURI);

    constructor(uint256 maxSupply)
        ERC721("Genesis DSO", "GDSO")
    {
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
        _idToGDSO[newItemId] = GDSO(newItemId, row, column, _tokenURI);
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        emit NewGDSO(msg.sender, newItemId, _tokenURI);
    }

    function updateURI(uint256 tokenId, string memory _tokenURI)
        public
        onlyCreator
    {
        _idToGDSO[tokenId].tokenUri = _tokenURI;
        _setTokenURI(tokenId, _tokenURI);
        emit URIUpdated(tokenId, _tokenURI);
    }

    function getGDSOsByOwner(address owner)
        external
        view
        returns (GDSO[] memory)
    {
        GDSO[] memory result = new GDSO[](ERC721.balanceOf(owner));
        uint256 counter = 0;
        for (uint256 i = 1; i < _tokenIds.current() + 1; i++) {
            if (ERC721.ownerOf(i) == owner) {
                result[counter] = _idToGDSO[i];
                counter++;
            }
        }
        return result;
    }

    function getAllGDSOs() external view returns (GDSO[] memory) {
        GDSO[] memory result = new GDSO[](_tokenIds.current());
        for (uint256 i = 1; i < _tokenIds.current() + 1; i++) {
            result[i - 1] = _idToGDSO[i];
        }
        return result;
    }

    function getGDSOById(uint256 _gdsoId) external view returns (GDSO memory) {
        GDSO memory result;
        if (_gdsoId > _tokenIds.current()) {
            revert("GDSOFactory: GDSO with specified id does not exist.");
        }
        result = _idToGDSO[_gdsoId];
        return result;
    }
}