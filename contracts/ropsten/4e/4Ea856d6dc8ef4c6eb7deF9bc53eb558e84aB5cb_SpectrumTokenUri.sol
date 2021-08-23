// SPDX-License-Identifier: GPL-v2-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./ITokenUriOracle.sol";
import "./vendor/base64.sol";

// Interpretation of cosmetic data in a token URI. This data is read starting
// from the most significant bit of the token URI, so new fields can be
// compatibly added to the *end* of the struct.
struct Cosmetics {
    uint24 rgb;
    uint8 alpha;
    uint16 width;
    uint16 height;
}

contract SpectrumTokenUri is ITokenUriOracle {
    using Strings for uint256;

    function tokenURI(address _tokenContract, uint256 _tokenId)
        external
        pure
        override
        returns (string memory)
    {
        _tokenContract;
        Cosmetics memory _cosmetics = _extractCosmetics(_tokenId);
        bytes memory _svgDataUri = abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64.encode(_svgBytes(_cosmetics))
        );
        bytes memory _spaceThenRgbString = _hexColor(" ", _cosmetics.rgb);
        string memory _widthString = uint256(_cosmetics.width).toString();
        string memory _heightString = uint256(_cosmetics.height).toString();
        bytes memory _alphaStringBuf = bytes("");
        if (_cosmetics.alpha != 255) {
            _alphaStringBuf = abi.encodePacked(
                " with alpha ",
                uint256(_cosmetics.alpha).toString(),
                "/255"
            );
        }
        // Note: concatenate in chunks of no more than 16 arguments, to work
        // around an internal compiler error in solc 0.8.4 when the optimizer
        // is enabled.
        bytes memory _jsonData = abi.encodePacked(
            '{"name":"Spectrum ',
            Strings.toHexString(_tokenId, 32),
            '","description":"',
            _widthString,
            "\\u00d7",
            _heightString,
            " rectangle filled with",
            _spaceThenRgbString,
            _alphaStringBuf,
            '.","image":"',
            _svgDataUri,
            '"}'
        );
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(_jsonData)
                )
            );
    }

    // `Strings.toHexString` results look like `0x123456`, but we want them to
    // look like `#123456`, so instead do a little surgery and require the
    // caller to supply an alternate first byte.
    function _hexColor(bytes1 _leadingByte, uint24 _rgb)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _buf = bytes(uint256(_rgb).toHexString(3));
        _buf[0] = _leadingByte;
        _buf[1] = "#";
        return _buf;
    }

    function _svgBytes(Cosmetics memory _cosmetics)
        internal
        pure
        returns (bytes memory)
    {
        uint256 _opacityBp = (uint256(_cosmetics.alpha) * 10000) / 255;
        string memory _widthString = uint256(_cosmetics.width).toString();
        string memory _heightString = uint256(_cosmetics.height).toString();
        bytes memory _quoteThenRgbString = _hexColor('"', _cosmetics.rgb);
        return
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ',
                _widthString,
                " ",
                _heightString,
                '"><path fill=',
                _quoteThenRgbString,
                '" fill-opacity="',
                _opacityBp.toString(),
                'e-4" d="M0 0H',
                _widthString,
                "V",
                _heightString,
                'H0z"/></svg>'
            );
    }

    function svg(uint256 _tokenId) external pure returns (string memory) {
        return string(_svgBytes(_extractCosmetics(_tokenId)));
    }

    function _extractCosmetics(uint256 _tokenId)
        internal
        pure
        returns (Cosmetics memory)
    {
        _tokenId >>= 192;
        uint16 _height = uint16(_tokenId);
        _tokenId >>= 16;
        uint16 _width = uint16(_tokenId);
        _tokenId >>= 16;
        uint8 _alpha = uint8(_tokenId);
        _tokenId >>= 8;
        uint24 _rgb = uint24(_tokenId);
        _tokenId >>= 24;
        return
            Cosmetics({
                rgb: _rgb,
                alpha: _alpha,
                width: _width,
                height: _height
            });
    }
}