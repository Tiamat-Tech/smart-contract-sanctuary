pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./utils/Minting.sol";
import "./utils/String.sol";

contract Felt is ERC721, AccessControl {
    mapping(uint256 => uint16) feltIds;
    mapping(uint256 => uint8) feltRarities;

    event FeltMinted(
        address to,
        uint256 amount,
        uint256 tokenId,
        uint16  feltId,
        uint8   feltRarity
    );

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    constructor(string memory baseURI)
    ERC721("Felts cute", "FELT")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        string memory uri = string(abi.encodePacked(
                baseURI,
                String.fromAddress(address(this)),
                "/"
            ));

        super._setBaseURI(uri);
    }

    function mintFor(
        address to,
        uint256 amount,
        bytes memory mintingBlob
    ) public onlyAdmin {
        (uint256 tokenId, uint16 feltId, uint8 feltRarity) = Minting.deserializeMintingBlob(mintingBlob);
        super._mint(to, tokenId);
        feltIds[tokenId] = feltId;
        feltRarities[tokenId] = feltRarity;

        emit FeltMinted(to, amount, tokenId, feltId, feltRarity);
    }

    function burn(uint256 tokenId) public onlyAdmin {
        super._burn(tokenId);
    }

    function getDetails(
        uint256 tokenId
    )
    public
    view
    returns (uint16 feltId, uint8 feltRarity)
    {
        return (feltIds[tokenId], feltRarities[tokenId]);
    }

}