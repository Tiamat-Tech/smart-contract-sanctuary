pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./utils/Minting.sol";
import "./utils/String.sol";

contract Momento is ERC721, AccessControl {
    mapping(uint256 => uint16) momentoEvent;
    mapping(uint256 => uint8) momentoGenre;

    event MomentoMinted(
        address to,
        uint256 amount,
        uint256 tokenId,
        uint16  proto,
        uint8   genre
    );

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    constructor(string memory baseURI)
        ERC721("Momento", "MMTO")
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
        (uint256 tokenId, uint16 proto, uint8 genre) = Minting.deserializeMintingBlob(mintingBlob);
        super._mint(to, tokenId);
        momentoEvent[tokenId] = proto;
        momentoGenre[tokenId] = genre;

        emit MomentoMinted(to, amount, tokenId, proto, genre);
    }

    function burn(uint256 tokenId) public onlyAdmin {
        super._burn(tokenId);
    }

    /**
     * @dev Retrieve the event and genre for a particular card represented by it's token id
     *
     * @param tokenId the id of the card you'd like to retrieve details for
     * @return proto The proto of the specified card
     * @return genre The genre of the specified card
     */
    function getDetails(
        uint256 tokenId
    )
        public
        view
        returns (uint16 proto, uint8 genre)
    {
        return (momentoEvent[tokenId], momentoGenre[tokenId]);
    }

}