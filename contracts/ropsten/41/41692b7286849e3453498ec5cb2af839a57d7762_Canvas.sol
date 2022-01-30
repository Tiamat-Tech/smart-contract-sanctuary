//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Canvas {
    uint32[100000][100000] public pixels;
    uint64 public width;
    uint64 public height;
    uint256 public changeCount = 0;
    address public owner;
    bool public isClosed = false;

    constructor(uint64 _width, uint64 _height) {
        console.log("Deploying a Canvas, width:", _width, " heigth:", _height);
        width = _width;
        height = _height;
        owner = msg.sender;
    }

    modifier checkIsClosed() {
        require(!isClosed, "Canvas is closed");
        _;
    }
    modifier onlyOwner() {
        require(owner == msg.sender, "onlyOwner");
        _;
    }

    function getPixelLine(uint32 i)
        public
        view
        returns (uint32[100000] memory)
    {
        return pixels[i];
    }

    function close() public onlyOwner {
        isClosed = true;
    }

    function draw(uint32[] calldata _pixels) public checkIsClosed {
        changeCount++;
        for (uint8 i = 0; i < _pixels.length; i += 2) {
            if (i > 2000) break;
            pixels[_pixels[i] / 100000][
                _pixels[i] - _pixels[i] / 100000
            ] = _pixels[i + 1];
        }
    }
}