// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.6;

import "./interfaces/IPixel.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "./interfaces/I1MIL.sol";


contract Pixel is IPixel, ERC721PresetMinterPauserAutoId {


    // TODO: Safe Math

    I1MIL public mil1;

    // TODO: Create accessors for price;
    uint256 public price = 1000;

    address[1000][1000] public pixelOwners;
    uint8[1000][1000] public pixelColors;

    mapping(address => string) private ownerUrls;

    constructor(I1MIL _mil1) ERC721PresetMinterPauserAutoId('Pixel', 'PXL', 'gateway.pinata.com/ipfs')  {
        mil1 = _mil1;
    }

    function getOneMilAddress() public view returns (I1MIL) {
        return mil1;
    }

    // TODO: Safe transfer

    function buy(uint xTopLeft, uint yTopLeft, uint xBottomRight, uint256 yBottomRight) public {
        uint256 numberPixels = (xBottomRight - xTopLeft) * (yBottomRight - yTopLeft);
        uint256 totalPrice = numberPixels * price;
        bool result = mil1.transferFrom(address(tx.origin), address(this), totalPrice);

        // TODO: optimize gas

        for (uint ix = xTopLeft; ix <= xBottomRight; ix++) {
            for (uint iy = yTopLeft; iy <= yBottomRight; iy++) {
                pixelOwners[ix][iy] = tx.origin;
            }
        }
    }

    function setColors(uint xTopLeft, uint yTopLeft, uint xBottomRight, uint256 yBottomRight, uint8[] memory colors) public {
        uint ic = 0;
        for (uint ix = xTopLeft; ix <= xBottomRight; ix++) {
            for (uint iy = yTopLeft; iy <= yBottomRight; iy++) {
                if (pixelOwners[ix][iy] == tx.origin) {
                    pixelColors[ix][iy] = colors[ic];
                }
                ic++;
            }
        }
    }

    function setUrl(string memory url) public {
        ownerUrls[tx.origin] = url;
    }

    function getPixelInfo(uint x, uint y) public view returns (uint8, string memory){
        return (pixelColors[x][y], ownerUrls[pixelOwners[x][y]]);
    }
}