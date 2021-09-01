// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Base64.sol";

contract Cranes is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Cranes", "CRNS") {}

    function safeMint(address to) public onlyOwner {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
      string[41] memory parts;
      string memory color0 = _randomRGB(tokenId, "COLOR0");
      string memory color1 = _randomRGB(tokenId, "COLOR1");
      string memory background = _randomRGB(tokenId, "BACKGROUND");
      string memory shadow = "rgb(0, 0, 0)";

      parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 314 314" xmlns:v="https://vecta.io/nano"><style>#K{animation:shadow 4s infinite linear;transform-origin:50% 75%}@keyframes shadow{0%{transform:scale(1)}50%{transform:scale(1.05)}100%{transform:scale(1)}}</style><defs><filter id="A" x="0" y="0"><feGaussianBlur in="SourceGraphic" stdDeviation="5"/></filter><linearGradient x1="17.028%" y1="80.949%" x2="86.755%" y2="21.255%" id="B"><stop stop-color="';
      parts[1] = color0;
      parts[2] = '" offset="0%"/><stop stop-color="';
      parts[3] = color1;
      parts[4] = '" offset="100%"/></linearGradient><linearGradient x1="50%" y1="92.043%" x2="61.228%" y2="79.915%" id="C"><stop stop-color="';
      parts[5] = color0;
      parts[6] = '" offset="0%"/><stop stop-color="';
      parts[7] = color0;
      parts[8] = '" offset="100%"/></linearGradient><linearGradient x1="45.274%" y1="50%" x2="57.468%" y2="89.513%" id="D"><stop stop-color="';
      parts[9] = color1;
      parts[10] = '" offset="0%"/><stop stop-color="';
      parts[11] = color0;
      parts[12] = '" offset="100%"/></linearGradient><linearGradient x1="76.452%" y1="19.303%" x2="24.94%" y2="100%" id="E"><stop stop-color="';
      parts[13] = color1;
      parts[14] = '" offset="0%"/><stop stop-color="';
      parts[15] = color0;
      parts[16] = '" offset="100%"/></linearGradient><linearGradient x1="36.227%" y1="44.325%" x2="59.155%" y2="25.95%" id="F"><stop stop-color="';
      parts[17] = color1;
      parts[18] = '" offset="0%"/><stop stop-color="';
      parts[19] = color0;
      parts[20] = '" offset="100%"/></linearGradient><linearGradient x1="-17.911%" y1="78.895%" x2="57.417%" y2="12.381%" id="G"><stop stop-color="';
      parts[21] = color1;
      parts[22] = '" offset="0%"/><stop stop-color="';
      parts[23] = color0;
      parts[24] = '" offset="100%"/></linearGradient><linearGradient x1="61.904%" y1="12.128%" x2="41.347%" y2="106.349%" id="H"><stop stop-color="';
      parts[25] = color1;
      parts[26] = '" offset="0%"/><stop stop-color="';
      parts[27] = color0;
      parts[28] = '" offset="100%"/></linearGradient><linearGradient x1="43.546%" y1="57.677%" x2="75.824%" y2="8.185%" id="I"><stop stop-color="';
      parts[29] = color1;
      parts[30] = '" offset="0%"/><stop stop-color="';
      parts[31] = color0;
      parts[32] = '" offset="100%"/></linearGradient><linearGradient x1="100%" y1="42.302%" x2="50%" y2="58.31%" id="J"><stop stop-color="';
      parts[33] = color1;
      parts[34] = '" offset="0%"/><stop stop-color="';
      parts[35] = color0;
      parts[36] = '" offset="100%"/></linearGradient></defs><path fill="';
      parts[37] = background;
      parts[38] = '" d="M0 0h314v314H0z"/><path d="m64.057 84 65.465 105.992 15.01-6.393 13.874-32.319 120.88-54.88-39.891 94.773c3.007.046 6.602 1.29 8.424 4.194l19.869 31.807 2.74 3.12-1.438-1.036.553.885-2.258-2.11-30.31-21.796-45.855 52.073-4.722 6.343-8.932 5.347-.012-.11-.025.11-13.832-21.611-127.883-31.035 64.769-34.154 5.238 1.492L64.057 84z" fill-opacity=".2" fill="';
      parts[39] = shadow;
      parts[40] = '" id="K" filter="url(#A)"/><g fill="none" fill-rule="evenodd"><animate attributeName="transform" values="translate(0 5);translate(0 -5);translate(0 5)" dur="4s" repeatCount="indefinite"/><path fill="url(#B)" d="M142 154.452l16.522-38.49L295 54l-48.952 116.301L199.945 198z"/><path fill="url(#C)" d="M103.455 164.354L52 40l84 136z"/><path fill="url(#D)" d="M165 145l20.382 27.003L200 191.371 179.396 206z"/><path fill="url(#E)" d="M180 249l10-6 59-67-7-9z"/><path d="M245.991 161.72c3.258-1.556 10.489-.754 13.482 4.017L284 205l-42-39.263 3.991-4.016z" fill="url(#F)"/><path d="M175 201.705l58.491-38.234c5.448-3.103 8.328-3.103 12.102-1.006 2.515 1.398 15.651 15.633 39.407 42.705l-38.399-27.613-4.034-4.024-52.44 70.43L180.042 250 175 201.705z" fill="url(#G)"/><path fill="url(#H)" d="M180 250l7-30-17 6-6-1z"/><path fill="url(#I)" d="M114 164.741L165.052 143 187 220z"/><path fill="url(#J)" d="M20 190.561L93.126 152l31.13 8.86L187 220.09 170.153 227z"/></g></svg>';

      string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8], parts[9], parts[10]));
      output = string(abi.encodePacked(output, parts[11], parts[12], parts[13], parts[14], parts[15], parts[16], parts[17], parts[18], parts[19], parts[20]));
      output = string(abi.encodePacked(output, parts[21], parts[22], parts[23], parts[24], parts[25], parts[26], parts[27], parts[28], parts[29], parts[30]));
      output = string(abi.encodePacked(output, parts[31], parts[32], parts[33], parts[34], parts[35], parts[36], parts[37], parts[38], parts[39], parts[40]));

      string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Crane #', _toString(tokenId), '", "description": "Cranes are little tokens of luck for special wallets", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));

      output = string(abi.encodePacked('data:application/json;base64,', json));

      return output;
    }

    function _randomRGB(uint256 tokenId, string memory key) internal pure returns (string memory) {
      string[5] memory parts;
      parts[0] = "rgb(";

      for(uint i = 1; i <= 3; i++) {
        uint256 rand = _random(string(abi.encodePacked(key, _toString(i), _toString(tokenId))));
        parts[i] = string(abi.encodePacked(_toString(rand % 255)));
      }
      string memory out = string(abi.encodePacked(parts[0], parts[1], ", ", parts[2], ", ", parts[3], ")"));
      return out;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
      super._beforeTokenTransfer(from, to, tokenId);
    }

    function _random(string memory input) internal pure returns (uint256) {
      return uint256(keccak256(abi.encodePacked(input)));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
      // Inspired by OraclizeAPI's implementation - MIT license
      // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

      if (value == 0) { return "0"; }
      uint256 temp = value;
      uint256 digits;
      while (temp != 0) {
        digits++;
        temp /= 10;
      }
      bytes memory buffer = new bytes(digits);
      while (value != 0) {
        digits -= 1;
        buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
        value /= 10;
      }
      return string(buffer);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
      return super.supportsInterface(interfaceId);
    }
}