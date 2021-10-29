// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SvgBuddy is ERC721URIStorage {

  struct RequestedNftDataSet {
      uint256 itemId;
      string name;
      string desc;
      string atts; // This is really a JSON hash, but it's flat by the time we get it here.
      string svg;
      address creator;
    }

  RequestedNftDataSet[] requestedNftDataSets;
  
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() ERC721("SvgBuddy", "SVGB") {}


  function mintNFT(address recipient, string memory name, string memory desc, string memory atts, string memory svg)
    public
    returns (uint256)
    {
        string memory tokenURI = generateTokenURI(name, desc, atts, svg);
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        // Is this too expensive? We could save this externally, but then we need a datastore.
        requestedNftDataSets.push(RequestedNftDataSet(newItemId, name, desc, atts, svg, _msgSender()));
        return newItemId;
    }

  function generateTokenURI(string memory name, string memory desc, string memory atts, string memory svg)
  pure
  private
  returns (string memory)
  {
    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name":',
            name,
            '","description":"', desc, '","attributes":',
            atts,
            ',"image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(svg)),
            '"}'
            )
          )
        )
      );

    string memory output = string(
      abi.encodePacked("data:application/json;base64,", json)
    );

    return output;
  } 
}

library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";
        uint256 encodedLen = 4 * ((len + 2) / 3);
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
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
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
}