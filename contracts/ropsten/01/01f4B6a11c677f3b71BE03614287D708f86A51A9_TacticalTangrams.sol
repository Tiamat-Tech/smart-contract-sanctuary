// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "base64-sol/base64.sol";

/**
 * @title TacticalTangrams
 * TacticalTangrams - a contract for Tactical Tangrams tans and tangram sets.
 */
contract TacticalTangrams /*is ERC721Tradable,*/ /*Base64Metadata*/ {
    constructor()//address _proxyRegistryAddress)
        //ERC721Tradable("TacticalTangrams", "TATA", _proxyRegistryAddress)
    {}

    // function baseTokenURI() override public pure returns (string memory) {
    //     return "https://creatures-api.opensea.io/api/creature/";
    // }

    function contractURI() external view returns (string memory) {
        string memory contentType = "data:application/json;base64,";

        return string(abi.encodePacked(
            contentType,
            Base64.encode(
                bytes(abi.encodePacked(
                    '{"name":"TacticalTangrams",',
                      '"description":"Tactical Tangrams NFT collection",',
                      '"image":"https://www.wired.com/images_blogs/wiredscience/2014/03/603px-Tangram_set_00.jpg",',
                      '"external_link":"https://tacticaltangrams.io",',
                      '"seller_fee_basis_points":100,',
                      '"fee_recipient":"',
                      getAddressString(),
                     '"}'
                 ))
             )
         ));
    }

    function getAddressString() internal view returns (string memory) {
        bytes memory s = new bytes(40);

        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(address(this))) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);            
        }

        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}