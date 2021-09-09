//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./Mintable.sol";
import "./utils/String.sol";

contract MomentoEvent is ERC721URIStorage, Ownable, Mintable{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    event EventToken(uint256 eventId, uint256 tokenId);


    //Event ID
    mapping(uint256 => uint256) private _eventID;
    //Event Name
    mapping(uint256 => string) private _eventName;
    //Token Type (participation, moment)
    enum TokenType{ PARTICIPATION, MOMENT }
    mapping(uint256 => TokenType) private _tokenType; //TODO , disallow transfer of participation token type
    //Event Creator's Address
    mapping(uint256 => address) private _eventCreator;

    //get functions for public

    //get event ID by tokenID
    function getEventID(uint256 tokenId) public view returns (uint256) {
        return _eventID[tokenId];
    }
    //get event name by tokenID
    function getEventName(uint256 tokenId) public view returns (string memory) {
        return _eventName[tokenId];
    }
    //get token type by tokenID
    function getTokenType(uint256 tokenId) public view returns (string memory) {
        return String.fromUint(uint(_tokenType[tokenId]));
    }
    //get event creator's address by tokenID
    function getEventCreator(uint256 tokenId) public view returns (address) {
        return _eventCreator[tokenId];
    }

    constructor(
        address _owner,
        address _imx
    ) ERC721("Momento Event Card", "MMTO") Mintable(_owner, _imx) {}

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        require(_tokenType[tokenId] == TokenType.MOMENT, "Participation Tokens Cannot be Transferred");

        _transfer(from, to, tokenId);
    }

    function _mintFor(
        address user,
        uint256 tmpTokenType,
        bytes memory blueprint
    ) internal override {
        (uint256 tmpEventID, string memory tmpEventName, address tmpEventCreator, string memory tmptokenUri) = _deserializeMintingBlob(blueprint);
        
        //Token Type Check
        bool error = false;
        TokenType finalTokenType = TokenType.MOMENT;
        if(tmpTokenType == 1){
            finalTokenType = TokenType.MOMENT;
        }else if(tmpTokenType == 2){
            finalTokenType = TokenType.PARTICIPATION;
        }else{
            error = true;
        }
        require(error == true, string(abi.encodePacked("Invalid Token Type Specified ", tmpTokenType)));
        _mintNFT(user, tmptokenUri, tmpEventID, tmpEventName, finalTokenType, tmpEventCreator);
    }

    function _mintNFT(address recipient, string memory tokenURI, uint256 tmpEventID, string memory tmpEventName, TokenType tmpTokenType, address tmpEventCreator)
        internal
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 tmpTokenId = _tokenIds.current();
        _safeMint(recipient, tmpTokenId);
        _setTokenURI(tmpTokenId, tokenURI);
        _eventID[tmpTokenId] = tmpEventID;
        _eventName[tmpTokenId] = tmpEventName;
        _tokenType[tmpTokenId] = tmpTokenType;
        _eventCreator[tmpTokenId] = tmpEventCreator;

        return tmpTokenId;
    }

    function _deserializeMintingBlob(bytes memory mintingBlob) internal pure returns (uint256, string memory, address, string memory) { //TODO
        string[] memory idParams = String.split(string(mintingBlob), ":"); //TODO
        
        // require(idParams.length == 3, string(abi.encodePacked("Invalid blob: Length: ",String.fromUint(idParams.length), " blob:", mintingBlob)));
        string memory tmpEventIDString = idParams[0];
        string memory tmpEventNameString = idParams[1];
        string memory tmpEventCreatorString = idParams[2];
        string memory tmpTokenUri = idParams[3];
        
        uint256 eventId = String.toUint(tmpEventIDString);
        address eventCreator = String.toAddress(tmpEventCreatorString);

        return (eventId, tmpEventNameString, eventCreator, tmpTokenUri);
    }
}