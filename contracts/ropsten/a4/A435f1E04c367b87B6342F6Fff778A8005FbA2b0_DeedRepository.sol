pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract DeedRepository is ERC721URIStorage {

    event DeedRegistered(address _by, uint256 _tokenId);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {

    }

    function registerDeed(uint256 _id, string memory _uri) public {
        _mint(msg.sender, _id);
        addMetadata(_id, _uri);
        emit DeedRegistered(msg.sender, _id);
    }

    function addMetadata(uint256 _tokenId, string memory _uri) public returns(bool) {
        _setTokenURI(_tokenId, _uri);
        return true;
    }
}