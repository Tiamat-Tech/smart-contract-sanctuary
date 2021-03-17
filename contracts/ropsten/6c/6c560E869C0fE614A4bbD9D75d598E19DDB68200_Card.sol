pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./utils/Minting.sol";
import "./utils/String.sol";
import "hardhat/console.sol";

contract Card is ERC721 {
    string private _baseURI = "https://api.immutable.com/asset/";

    mapping(uint256 => uint16) public cardProtos;
    mapping(uint256 => uint8) public cardQualities;

    event CardMinted(
        address to,
        uint256 tokenId,
        uint16 proto,
        uint8 quality
    );

    constructor()
        public
        ERC721("Gods Unchained", "GU")
    {
        string memory uri = string(abi.encodePacked(
            _baseURI,
            String.fromAddress(address(this)),
            "/"
        ));

        super._setBaseURI(uri);
    }

    function mintFor(
        address to,
        uint256,
        bytes memory mintingBlob
    ) public {
        uint256 tokenId;
        uint16 proto;
        uint8 quality;

        (tokenId, proto, quality) = Minting.deserializeMintingBlob(mintingBlob);
        cardProtos[tokenId] = proto;
        cardQualities[tokenId] = quality;
        super._mint(to, tokenId);
        emit CardMinted(to, tokenId, proto, quality);
    }

    /**
     * @dev Retrieve the proto and quality for a particular card represented by it's token id
     *
     * @param tokenId the id of the card you'd like to retrieve details for
     * @return proto The proto of the specified card
     * @return quality The quality of the specified card
     */
    function getDetails(
        uint256 tokenId
    )
        public
        view
        returns (uint16 proto, uint8 quality)
    {
        require(_exists(tokenId), "getDetails for nonexistent token");
        return (cardProtos[tokenId], cardQualities[tokenId]);
    }
}