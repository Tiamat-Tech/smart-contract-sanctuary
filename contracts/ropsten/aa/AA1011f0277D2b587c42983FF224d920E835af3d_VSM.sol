// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMintable.sol";
import "./utils/Bytes.sol";
import "./utils/Minting.sol";

contract VSM is ERC721, AccessControl, Ownable, IMintable {
    bool public frozen = false;

    mapping(uint256 => string) private _itemIds;
    string private _tokenBaseURI;

    // Create a new role identifier for the moderator role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor(
        address[] memory operators
    ) ERC721("VSM01", "VSM_01") {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        for (uint256 i = 0; i < operators.length; i++) {
            require(operators[i] != address(0), "Can't add the null address");
            _setupRole(OPERATOR_ROLE, operators[i]);
        }
    }

    function freezeBaseURI() public onlyOwner {
        frozen = true;
    }

    function setBaseURI(string memory baseURI)
        public
        onlyRole(OPERATOR_ROLE)
    {
        require(!frozen, "Contract is frozen");
        require(_hasLength(baseURI), "Need a valid URI");

        _tokenBaseURI = baseURI;
    }

    function getItemId(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Operator query for nonexistent token");

        return _itemIds[tokenId];
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");

        _burn(tokenId);
        delete _itemIds[tokenId];
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    )
        external
        override
        onlyRole(OPERATOR_ROLE)
    {
        require(quantity == 1, "Mintable: invalid quantity");
        (uint256 id, bytes calldata blueprint) = Minting.split(mintingBlob);
        _mintFor(user, id, blueprint);
    }

    function _mintFor(
        address user,
        uint256 id,
        bytes calldata blueprint
    ) internal {
        require(blueprint.length > 0, "itemId must be specified");

        _itemIds[id] = Bytes.substring(blueprint, 0, blueprint.length);
        _safeMint(user, id);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    function _hasLength(string memory str) internal pure returns (bool) {
        return bytes(str).length > 0;
    }
}