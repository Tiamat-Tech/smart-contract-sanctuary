// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IMintable.sol";
import "./utils/Minting.sol";

contract Felt is ERC721, Ownable, IMintable {
    address public imx;
    string public baseURI;
    mapping(uint256 => uint16) feltIds;
    mapping(uint256 => uint8) feltRarities;
    mapping(uint16 => string) feltHashes;

    event FeltMinted(
        address user,
        uint256 quantity,
        uint256 tokenId,
        uint16  feltId,
        uint8   feltRarity,
        string   feltHash);

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx,
        string memory _uri) ERC721(_name, _symbol) {
        imx = _imx;
        baseURI = _uri;
        require(_owner != address(0), "Owner must not be empty");
        transferOwnership(_owner);
    }

    modifier onlyIMX() {
        require(msg.sender == imx, "Function can only be called by IMX");
        _;
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata blob
    ) external override onlyIMX {
        require(quantity == 1, "Mintable: invalid quantity");
        (uint256 tokenId, uint16 feltId, uint8 feltRarity, string memory feltHash) = Minting.split(blob);
        require(keccak256(abi.encodePacked(feltHashes[(feltId*10) + feltRarity])) == keccak256(abi.encodePacked(feltHash)) || keccak256(abi.encodePacked(feltHashes[(feltId*10) + feltRarity])) == keccak256(abi.encodePacked("")), "Can't change hash of already minted NFT.");
        _safeMint(user, tokenId);
        feltIds[tokenId] = feltId;
        feltRarities[tokenId] = feltRarity;
        feltHashes[(feltId*10) + feltRarity] = feltHash;
        emit FeltMinted(user, quantity, tokenId, feltId, feltRarity, feltHash);
    }

    function getDetails(
        uint256 tokenId
    )
    public
    view
    returns (uint16 feltId, uint8 feltRarity, string memory feltHash)
    {
        return (feltIds[tokenId], feltRarities[tokenId], feltHashes[(feltIds[tokenId] * 10) + feltRarities[tokenId]]);
    }

    function tokenURI(uint256 tokenId) public view override returns(string memory) {

        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory uri = _baseURI();
        return bytes(uri).length > 0 ? string(abi.encodePacked(uri, feltHashes[(feltIds[tokenId] * 10) + feltRarities[tokenId]])) : "";
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}