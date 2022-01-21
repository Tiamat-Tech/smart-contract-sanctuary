// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract VSM is ERC721, Mintable {
    bool public frozen = false;

    enum PassType {
        ACCESS,
        INDUSTRY,
        FOUNDER
    }

    struct ItemInfo {
        string itemId;
        PassType passType;
    }

    mapping(uint256 => ItemInfo) private _itemInfos;
    string private _tokenBaseURI;

    constructor(
        address _operator
    ) ERC721("VSM01", "VSM_01") Mintable(_operator) {}

    function freezeBaseURI() public onlyOwner {
        frozen = true;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        require(!frozen, "Contract is frozen");
        require(_hasLength(baseURI), "Need a valid URI");

        _tokenBaseURI = baseURI;
    }

    function setPassType(uint256 tokenId, PassType pass) public onlyOwner {
        require(_exists(tokenId), "Operator query for nonexistent token");

        _itemInfos[tokenId].passType = pass;
    }

    function getPassType(uint256 tokenId) public view returns (PassType) {
        require(_exists(tokenId), "Operator query for nonexistent token");

        return _itemInfos[tokenId].passType;
    }

    function getItemId(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Operator query for nonexistent token");

        return _itemInfos[tokenId].itemId;
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");

        _burn(tokenId);
        delete _itemInfos[tokenId];
    }

    function _mintFor(
        address user,
        uint256 id,
        bytes calldata blueprint
    ) internal override {
        _parseItemInfo(id, blueprint);

        _safeMint(user, id);
    }

    function _parseItemInfo(uint256 tokenId, bytes calldata blueprint) internal {
        int256 index = Bytes.indexOf(blueprint, ",", 0);
        require(index >= 0, "Separator must exist");
        uint256 passType = Bytes.toUint(blueprint[0:uint256(index)]);
        uint256 itemIdLength = blueprint.length - uint256(index) - 1;
        require(itemIdLength >= 0, "ItemId must be specified");

        string memory itemId = Bytes.substring(blueprint, uint256(index) + 1, blueprint.length);
        _itemInfos[tokenId] = ItemInfo(itemId, PassType(passType));
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    function _hasLength(string memory str) internal pure returns (bool) {
        return bytes(str).length > 0;
    }
}