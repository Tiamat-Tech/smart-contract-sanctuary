// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";
import "./utils/ERC2981.sol";
import "./utils/String.sol";

contract MomentoEvent is ERC721URIStorage, Ownable, Mintable, ERC2981{

    //Token Type (participation, moment)
    enum TokenType{ PARTICIPATION, MOMENT }
    mapping(uint256 => TokenType) private _tokenType;
    //Event Creator's Address
    mapping(uint256 => address) private _eventCreator;

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
        uint256 tokenID,
        bytes memory blueprint
    ) internal override {
        (address tmpEventCreator, string memory tmpTokenType, string memory tmptokenUri, uint256 tmpPercent) = _deserializeMintingBlob(blueprint);
        
        //Token Type Check
        bool error = false;
        TokenType finalTokenType = TokenType.MOMENT;
        if(String.compareStrings(tmpTokenType, "MOMENT")){
            finalTokenType = TokenType.MOMENT;
        }else if(String.compareStrings(tmpTokenType, "PARTICIPATION")){
            finalTokenType = TokenType.PARTICIPATION;
        }else{
            error = true;
        }

        require(error == false, string(abi.encodePacked("Invalid Token Type Specified ", tmpTokenType)));
        _mintNFT(user, tmptokenUri, tokenID, finalTokenType, tmpEventCreator, tmpPercent);
    }

    function _mintNFT(address recipient, string memory tokenURI, uint256 tmpTokenId, TokenType tmpTokenType, address tmpEventCreator, uint256 percent)
        internal
        returns (uint256)
    {
        _safeMint(recipient, tmpTokenId);
        _setTokenURI(tmpTokenId, tokenURI);
        _tokenType[tmpTokenId] = tmpTokenType;
        _eventCreator[tmpTokenId] = tmpEventCreator;

        //Royalty Stuff
        uint256 royalty = percent / 100;
        _setReceiver(tmpTokenId, tmpEventCreator);
        _setRoyaltyPercentage(tmpTokenId, royalty);

        return tmpTokenId;
    }

    function _deserializeMintingBlob(bytes memory mintingBlob) internal pure returns (address, string memory, string memory, uint256) { 
        string[] memory idParams = String.split(string(mintingBlob), ";");
        
        // require(idParams.length == 2, "Token Count Mismatch");
        string memory tmpEventCreatorString = idParams[0];
        string memory tmpTokenType = idParams[1];
        string memory tmpTokenUri = idParams[2];
        string memory tmpPercent = idParams[3];
        
        address eventCreator = String.toAddress(tmpEventCreatorString);
        uint256 percent = String.toUint(tmpPercent);

        return (eventCreator, tmpTokenType, tmpTokenUri, percent);
    }
    
}