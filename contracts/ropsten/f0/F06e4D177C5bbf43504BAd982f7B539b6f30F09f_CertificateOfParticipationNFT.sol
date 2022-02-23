// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract CertificateOfParticipationNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("CertificateOfParticipationNFT", "COP") {
    }

    function generateTokenURL(string memory participentName) public pure returns (string memory){
        string memory imageURL = 'ipfs://QmPzGemrUG93AoJwR6Vb6Arj4iYWCeyY5zvWTmXzjihFCf';
        string memory empty = '';
        if (keccak256(bytes(participentName)) == keccak256(bytes(empty))) {
            participentName = 'Anonymous';
        }
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Certificate Of Participation: Smart", "description": "This NFT certify that the original holder joined the Smart Contracts training session", "image_data": "', imageURL, '", "attributes":[{ "trait_type": "Name", "value": "', participentName,'" }]}'))));
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function getCertificate(address student, string memory participentName) public returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(student, newItemId);
        _setTokenURI(newItemId, generateTokenURL(participentName));

        return newItemId;
    }
}