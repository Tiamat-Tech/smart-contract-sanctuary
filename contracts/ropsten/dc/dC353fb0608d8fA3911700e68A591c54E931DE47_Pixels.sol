// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Pixels is ERC721, Ownable {

    uint256 public _gridsize = 10; //will change to 1000 eventually.....l
    uint256 public _totalPixels = _gridsize * _gridsize;
    uint256 public _pixelPrice = 250000000000000; // approx 1usd

    // bytes3[] public _pixelColours = new bytes3[](_gridsize);
    mapping(uint256 => bytes3) public _pixelColours;
    mapping(uint256 => bool) public _pixelOwned;

    event PixelMinted (uint date, address to, uint256 pixelId);
    event PixelColourChanged ( address owner, bytes3 newColour, uint256 pixelId );

    constructor() ERC721("Pixels", "PIX") {}

    function mint(uint256 _pixelId, bytes3 _newColour) public payable {
        require(!_pixelOwned[_pixelId], "Pixel is already owned");
        require(_pixelId < _totalPixels, "Pixel out of range");
        require(msg.value >= _pixelPrice, 'No/ Insufficient fees provided');
        _pixelOwned[_pixelId] = true;
        _pixelColours[_pixelId] = _newColour;
        _safeMint(msg.sender, _pixelId);
        emit PixelMinted(block.timestamp, msg.sender, _pixelId);
    }

    function mint(uint256 _pixelId) external payable {
        mint(_pixelId, 0x111111);
    }

    function getBalance() public view returns(uint256){
        return address(this).balance;
    }

     function withdrawAmount(uint256 amount) external onlyOwner {
         require(amount <= getBalance(), "Insufficient funds");
         payable(msg.sender).transfer(amount);
     }

    //function change pixel colour |||ERC721.ownerOf(tokenId)
    function changePixelColor(uint256 _pixelId, bytes3 _colorHex) external {
        require(_pixelId < _totalPixels, "Pixel id out of range");
        require(ownerOf(_pixelId) == msg.sender, "Sender is not Pixel owner");
        _pixelColours[_pixelId] = _colorHex;
        emit PixelColourChanged(msg.sender, _colorHex, _pixelId);
    }

    function getPixelColour(uint256 _pixelId) public view returns (bytes3) {
        require(_pixelId < _totalPixels, "Pixel id out of range");
        if(_pixelOwned[_pixelId]) {
            return _pixelColours[_pixelId];
        } else {
            return 0x000001;
        }
    }

    function isPixelOwned(uint256 _pixelId) public view returns (bool) {
        require(_pixelId < _totalPixels, "Pixel id out of range");
        return _pixelOwned[_pixelId];
    }
}