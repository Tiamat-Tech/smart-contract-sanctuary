// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract VSM is ERC721, Mintable {
    bool public frozen = false;

    mapping(uint256 => string) private _items;
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

    function getItemId(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Operator query for nonexistent token");

        return _items[tokenId];
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");

        _burn(tokenId);
        delete _items[tokenId];
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
        require(blueprint.length > 0, "ItemId must be specified");

        _items[tokenId] = Bytes.substring(blueprint, 0, blueprint.length);
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    function _hasLength(string memory str) internal pure returns (bool) {
        return bytes(str).length > 0;
    }
}