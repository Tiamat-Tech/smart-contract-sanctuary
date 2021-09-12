// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import '@openzeppelin/contracts/utils/Strings.sol';

contract Hodl2 is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;

    mapping(address => uint256) private _mintedList;

    address public RESERVED_ADDRESS = 0xA6b42f9D0eb06AA40FcAa2E368cED1A8aa6761b5;
    uint256 public MAX_PER_ADDRESS = 100;
    uint256 public MAX_RESERVED = 1000;
    
    uint256 public maxPublic = 10;
    uint256 public totalReservedSupply = 0;
    uint256 public totalPublicSupply = 0;
    uint256 public temporaryPublicMax = 0;

    function totalSupply() public view returns (uint) {
        return totalReservedSupply + totalPublicSupply;
    }

    constructor() ERC721("HODL TOKEN23", "HODL22") {
    }
    
    function setTemporaryPublicMax(uint256 _temporaryPublicMax) public onlyOwner {
        require(_temporaryPublicMax <= maxPublic, "You cannot set the temporary max above the absolute total.");
        
        temporaryPublicMax = _temporaryPublicMax;
    }

    function mintPublic() public {
        require(_mintedList[msg.sender] < MAX_PER_ADDRESS, "You have reached your minting limit.");
        require(totalPublicSupply < maxPublic, "There are no more NFTs for public minting.");
        require(totalPublicSupply < temporaryPublicMax, "There are no more NFTs for public minting at this time.");
        
        _mintedList[msg.sender] += 1;
        totalPublicSupply += 1;
        
        uint256 tokenId = totalReservedSupply + totalPublicSupply;
        
        _safeMint(msg.sender, tokenId);
    }
    
    function mintReserved(uint256 amount) external {
        require(RESERVED_ADDRESS == msg.sender, "You are not on the reserve white list.");
        require(totalReservedSupply + amount <= MAX_RESERVED, "This would exceed the total number of reserved NFTs.");

        for(uint256 i = 0; i < amount; i++) {
          totalReservedSupply += 1;
           uint256 tokenId = totalReservedSupply + totalPublicSupply;
          _safeMint(msg.sender, tokenId);
        }
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }


    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        string memory text = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">Test</text><</svg>';

        string memory output = string(abi.encodePacked(text));
        
        string memory json = Base64Encode(bytes(string(abi.encodePacked('{"name": "Test', tokenId, '", "description": "Test desc.", "image": "data:image/svg+xml;base64,', Base64Encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function Base64Encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
    // function dataURI(uint256 tokenId) public view override returns (string memory) {
    //     require(_exists(tokenId), 'NounsToken: URI query for nonexistent token');
    //     return descriptor.dataURI(tokenId, seeds[tokenId]);
    // }

}