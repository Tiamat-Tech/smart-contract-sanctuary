// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @creator: redeem.coffee
/// @author: Wizard

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./ERC721Redeemable.sol";

contract Redeemable is
    ERC721,
    ERC721Burnable,
    ERC721Redeemable,
    Ownable,
    AccessControl
{
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    constructor() ERC721("Redeemable", "REDEM") {
        _setupRole(CONTROLLER_ROLE, _msgSender());
    }

    modifier onlyController() {
        require(
            hasRole(CONTROLLER_ROLE, _msgSender()),
            "caller is not a controller"
        );
        _;
    }

    function create(
        uint256 id,
        uint256 allowedRedemptions,
        uint256 expiresAt,
        string memory uri
    ) public onlyController {
        _create(id, allowedRedemptions, expiresAt, uri);
    }

    function setBaseURI(uint256 redeemable, string memory uri)
        public
        onlyController
    {
        _setBaseURI(redeemable, uri);
    }

    function mint(uint256 prefix, address to) public onlyController {
        _mint(prefix, to);
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721Redeemable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}