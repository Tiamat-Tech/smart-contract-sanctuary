/*
THE SHATTERING
a blitmap derivative

@author fishboy
*/


// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "hardhat/console.sol";
import {IBlitmap} from "../interfaces/IBlitmap.sol";
import {BlitmapHelper} from '../libraries/BlitmapHelper.sol';
import {Base64} from '../libraries/Base64.sol';

contract Shattered is ERC721Enumerable, ReentrancyGuard, Ownable {

	using BytesLib for bytes;

    bool public _live = true;

    uint256 private constant TOTAL_SUPPLY = 1700 * 4;

    address private _blitmapContractAddress;

    IBlitmap private _blitmapContract;

    address private _owner;

    uint256[] private _blitRange;

    mapping(uint256 => AllPieces) _tokenPieces;

    mapping(uint256 => BlitmapPieces) _usedPieces;

    struct BlitmapPieces {
        bool tlUsed;
        bool trUsed;
        bool blUsed;
        bool brUsed;
        bool exists;
    }

    struct Piece {
        uint256 tid;
        bool exists;
    }

    struct AllPieces {
        Piece topLeft;
        Piece topRight;
        Piece bottomLeft;
        Piece bottomRight;
    }

    string[32] private lookup = [
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
        '11', '12', '13', '14', '15', '16', '17', '18', '19',
        '20', '21', '22', '23', '24', '25', '26', '27', '28', '29',
        '30', '31'
    ];

    constructor(address blitmapAddr) ERC721("Shattered Map", "SMAPS") {
        _blitmapContract = IBlitmap(blitmapAddr);
    }

    function getPiece(bytes memory tokenData, uint256 startAt, uint256 pad) private pure returns (bytes memory) {
        bytes memory square;
        bytes memory colors = tokenData.slice(0, 12);
        uint256 startingAt = startAt;
        for (uint256 i = 1; i <= 16; i++) {
            square = square.concat(tokenData.slice(startingAt + pad, 4));
            startingAt += 8;
        }

        return colors.concat(square);
    }

    function getRect(string memory x, string memory y, string memory color) private pure returns (string memory) {
        return string(abi.encodePacked('<rect fill="', color, '" x="', x, '" y="', y, '" width="1.5" height="1.5" />'));
    }

    function tokenDataOf(uint256 tokenId) public view returns (bytes memory) {
        bytes memory tokenData;
        if (_tokenPieces[tokenId].topLeft.exists) {
            tokenData = tokenData.concat(
                getPiece(
                    _blitmapContract.tokenDataOf(_tokenPieces[tokenId].topLeft.tid), 12, 0
                )
            );
        }
        if (_tokenPieces[tokenId].topRight.exists) {
            tokenData = tokenData.concat(
                getPiece(
                    _blitmapContract.tokenDataOf(_tokenPieces[tokenId].topRight.tid), 12, 4
                )
            );
        }
        if (_tokenPieces[tokenId].bottomLeft.exists) {
            tokenData = tokenData.concat(
                getPiece(
                    _blitmapContract.tokenDataOf(_tokenPieces[tokenId].bottomLeft.tid), 136, 4
                )
            );
        }
        if (_tokenPieces[tokenId].bottomRight.exists) {
            tokenData = tokenData.concat(
                getPiece(
                    _blitmapContract.tokenDataOf(_tokenPieces[tokenId].bottomRight.tid), 144, 0
                )
            );
        }

        return tokenData;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"Shattered Map", "description":"Test", "image":"',tokenSvgDataOf(tokenId),'"}'
                            )
                        )
                    )
                )
            );
    }

    function getBit(bytes1 b, uint8 loc) internal pure returns (uint8) {
        return uint8(b) >> loc & 1;
    }

    function buildLine(bytes1 data, uint256 x, uint256 y, string[4] memory colors) private view returns (string memory) {
        return string(abi.encodePacked(
            getRect(
                lookup[x], lookup[y], colors[BlitmapHelper.getColorToUse(getBit(data, 6), getBit(data, 7))]
            ),
            getRect(
                lookup[x+1], lookup[y], colors[BlitmapHelper.getColorToUse(getBit(data, 4), getBit(data, 5))]
            ),
            getRect(
                lookup[x+2], lookup[y], colors[BlitmapHelper.getColorToUse(getBit(data, 2), getBit(data, 3))]
            ),
            getRect(
                lookup[x+3], lookup[y], colors[BlitmapHelper.getColorToUse(getBit(data, 0), getBit(data, 1))]
            )
        ));
    }

    function draw(uint256 startX, uint256 startY, uint256 limit, bytes memory tokenData, string[4] memory colors) private view returns (string memory) {
        uint256 x = startX;
        uint256 y = startY;
        string[8] memory row;
        string memory svgString;
        for (uint256 i = 12; i < tokenData.length; i+=8) {
            row[0] = buildLine(tokenData[i], x, y, colors);
            x += 4;
            row[1] = buildLine(tokenData[i+1], x, y, colors);
            x += 4;
            row[2] = buildLine(tokenData[i+2], x, y, colors);
            x += 4;
            row[3] = buildLine(tokenData[i+3], x, y, colors);
            x += 4;
            
            if (x >= limit) {
                x = startX;
                y += 1;
            }
            
            row[4] = buildLine(tokenData[i+4], x, y, colors);
            x += 4;
            row[5] = buildLine(tokenData[i+5], x, y, colors);
            x += 4;
            row[6] = buildLine(tokenData[i+6], x, y, colors);
            x += 4;
            row[7] = buildLine(tokenData[i+7], x, y, colors);
            x += 4;

            if (x >= limit) {
                x = startX;
                y += 1;
            }

            svgString = string(abi.encodePacked(svgString, row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7]));
        }

        return svgString;
    }

    function tokenSvgDataOf(uint256 tokenId) public view returns (string memory) {
        bytes memory tokenData = tokenDataOf(tokenId);
        bool fullSquare = tokenData.length > 76;
        string memory dims = fullSquare ? '128' : '16';
        string memory svgString = string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8" standalone="no"?><svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 ',
            dims,
            ' ',
            dims,
            '">'));
        string[4] memory colors;
        uint256 square = 0;
        for (uint256 i = 0; i < tokenData.length; i+=76) {
            bytes memory data = tokenData.slice(i, 76);
            colors =  BlitmapHelper.getColorsAsHex(data);
            bool left = square % 2 == 0;
            bool top = i < 152;
            svgString = string(abi.encodePacked(svgString, draw(left ? 0 : 16, top ? 0 : 16, left ? 16 : 32, data, colors)));
            square++;
        }

        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64.encode(abi.encodePacked(svgString, "</svg>"))));   
    }

    function getRange() public view returns (uint256[] memory) {
        return _blitRange;
    }

    function mintPiece(uint256 blitTokenId) public nonReentrant payable {
        require(_live == true, 'Minting must be live');
        require(totalSupply() <= TOTAL_SUPPLY, 'Total supply has been minted');
        
        uint256 tokenId = totalSupply();
        uint256 bToken = blitTokenId % 4;
        if (_usedPieces[bToken].exists == true) {
            if (_usedPieces[bToken].trUsed == false) {
                _usedPieces[bToken].trUsed = true;
                _tokenPieces[tokenId].topRight = Piece(bToken, true);
            }
            else if (_usedPieces[bToken].blUsed == false) {
                _usedPieces[bToken].blUsed = true;
                _tokenPieces[tokenId].bottomLeft = Piece(bToken, true);
            }      
            else if (_usedPieces[bToken].brUsed == false) {
                _usedPieces[bToken].brUsed = true;
                _tokenPieces[tokenId].bottomRight = Piece(bToken, true);
            }
        } else {
            BlitmapPieces memory blitmapPiece = BlitmapPieces(true, false, false, false, true);
            AllPieces memory allPieces = AllPieces(Piece(bToken, true), Piece(0, false), Piece(0, false), Piece(0, false));
            _usedPieces[bToken] = blitmapPiece;
            _tokenPieces[tokenId] = allPieces;
        }

        _safeMint(_msgSender(), tokenId);
    }

    function mintCollage(uint256 firstId, uint256 secondId, uint256 thirdId, uint256 fourthId) public nonReentrant payable {
        require(_msgSender() == ownerOf(firstId), 'Piece not owned');
        require(_msgSender() == ownerOf(secondId), 'Piece not owned');
        require(_msgSender() == ownerOf(thirdId), 'Piece not owned');
        require(_msgSender() == ownerOf(fourthId), 'Piece not owned');
        
        AllPieces memory allPieces = AllPieces(
            _tokenPieces[firstId].topLeft, 
            _tokenPieces[secondId].topRight, 
            _tokenPieces[thirdId].bottomLeft, 
            _tokenPieces[fourthId].bottomRight
            );
            
        uint256 combinedTokenId = totalSupply();
        _tokenPieces[combinedTokenId] = allPieces;

        _burn(firstId);
        _burn(secondId);
        _burn(thirdId);
    }

    function tokenPieces(uint256 tokenId) public view returns (AllPieces memory) {
        return _tokenPieces[tokenId];
    }

    function usedBlitmapPieces(uint256 tokenId) public view returns (BlitmapPieces memory) {
        return _usedPieces[tokenId];
    }

    function setLive(bool live) public onlyOwner {
        _live = live;
    }
}