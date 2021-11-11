// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

//import "./ERC721Tradable.sol";
import "./Base64Metadata.sol";

/**
 * @title TacticalTangrams
 * TacticalTangrams - a contract for Tactical Tangrams tans and tangram sets.
 */
contract TacticalTangrams is /*ERC721Tradable,*/ Base64Metadata {
    constructor()//address _proxyRegistryAddress)
        //ERC721Tradable("TacticalTangrams", "TATA", _proxyRegistryAddress)
    {}

    // function baseTokenURI() override public pure returns (string memory) {
    //     return "https://creatures-api.opensea.io/api/creature/";
    // }

    function contractURI() external view returns (string memory) {
        return encodeData(
            bytes(
                abi.encodePacked(
                    '{"name":"TacticalTangrams","description":"Tactical Tangrams NFT collection","image":"https://de.wikipedia.org/wiki/Tangram#/media/Datei:Tangram_diagram.svg","external_link":"https://tacticaltangrams.io","seller_fee_basis_points": 100, "fee_recipient": "',
                    address(this),
                    '"}')
                ));
    }
}