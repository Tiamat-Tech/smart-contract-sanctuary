// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ContractControlList.sol";


/**
 * @title ERC721Tradable
 * Land NFT - ERC721 contract that whitelists a trading address, has minting functionality and is able to store own shape.
 */
contract Land is ERC721Enumerable, Ownable {

    string constant tokenUri = "http://token_uri.com/";

    // Coordinate struct containing geo location of Land.
    struct Coordinate {
        uint256 latitude;
        uint256 longitude;
    }
    mapping(uint256 => Coordinate[]) internal coordinates;
    mapping(uint256 => uint256) internal coordinatesLen;
    ContractControlList internal contractControlList;

    constructor(string memory name_, string memory symbol_, ContractControlList contractControlList_) ERC721(name_, symbol_) Ownable() {
        contractControlList = contractControlList_;
    }

    modifier onlyRole(bytes32 role) {
        contractControlList.checkRole(role, msg.sender);
        _;
    }

    /**
     * @dev Mints a token to an address with a tokenURI.
     * @param to_ address of the future owner of the token
     */
    function mintTo(address to_, uint256 tokenId_) external onlyRole(contractControlList.LAND_MINTER_ROLE()) {
        _mint(to_, tokenId_);
    }

    /**
     * @dev Mints a token to msg.signer.
     */
    function mint(uint256 tokenId_) external onlyRole(contractControlList.LAND_MINTER_ROLE()) {
        _mint(msg.sender, tokenId_);
    }

    /**
    * @dev Sets Land coordinates.
    * @param tokenId_ Id of the land
    * @param coordinates_ Array of multi-polygon land shape
     */
    function setCoordinates(uint256 tokenId_, Coordinate[] memory coordinates_) external  onlyRole(contractControlList.LAND_OWNER_ROLE()) {
        delete coordinates[tokenId_];
        coordinatesLen[tokenId_] = 0;

        for (uint256 i = 0; i < coordinates_.length; i++) {
            coordinates[tokenId_][i] = coordinates_[i];
        }

        coordinatesLen[tokenId_] = coordinates_.length;
    }

    /**
    * @dev Returns land coordinates
    * @param tokenId_ Id of the land
     */
    function getCoordinates(uint256 tokenId_) external view returns(Coordinate[] memory) {
        return coordinates[tokenId_];
    }

    /**
     * @dev returns uri where resources are hosted
     */
    function baseTokenURI() external pure returns (string memory) {
        return tokenUri;
    }

    /**
     * @dev returns uri where particular token is hosted
     */
    //slither-disable-next-line
    function tokenURI(uint256 tokenId_) override public pure returns (string memory) {
        return string(abi.encodePacked(tokenUri, Strings.toString(tokenId_)));
    }
}