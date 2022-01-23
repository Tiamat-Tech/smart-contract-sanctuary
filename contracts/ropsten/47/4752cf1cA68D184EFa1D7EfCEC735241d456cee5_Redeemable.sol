// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721/ERC721Redeemable.sol";
import "./royalties/ERC2981PerTokenRoyalties.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Redeemable is
    ERC721,
    ERC721Burnable,
    ERC721Redeemable,
    ERC2981PerTokenRoyalties,
    Ownable,
    AccessControl
{
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    string private _contractURI;

    constructor() ERC721("Redeemable", "REDEM") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CONTROLLER_ROLE, _msgSender());
    }

    modifier onlyController() {
        require(
            hasRole(CONTROLLER_ROLE, _msgSender()),
            "caller is not a controller"
        );
        _;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function setContractURI(string memory uri) public onlyOwner {
        _contractURI = uri;
    }

    function setBaseURI(uint256 redeemable, string memory uri)
        public
        onlyController
    {
        _setBaseURI(redeemable, uri);
    }

    function create(
        uint256 id,
        uint256 allowedRedemptions,
        uint256 expiresAt,
        string memory uri,
        address royaltyRecipient,
        uint256 royaltyValue
    ) public onlyController {
        _create(id, allowedRedemptions, expiresAt, uri);

        if (royaltyValue > 0) {
            _setTokenRoyalty(id, royaltyRecipient, royaltyValue);
        }
    }

    function mint(uint256 prefix, address to) public onlyController {
        _mint(prefix, to);
    }

    function royaltyInfo(uint256 tokenId, uint256 value)
        external
        view
        override(ERC2981PerTokenRoyalties)
        returns (address receiver, uint256 royaltyAmount)
    {
        uint256 redeemableId = redeemableIdForTokenId(tokenId);
        RoyaltyInfo memory royalties = _royalties[redeemableId];
        receiver = royalties.recipient;
        royaltyAmount = (value * royalties.amount) / 10000;
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
        override(ERC721, ERC2981Base, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }
}