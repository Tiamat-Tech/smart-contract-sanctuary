// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Pixels is ERC721, Ownable {

    uint256 public _gridsize = 32;
    uint256 public _totalPixels = _gridsize * _gridsize;
    uint256 public _pixelPrice = 250000000000000; // approx 1usd

    // bytes3[] public _pixelColours = new bytes3[](_gridsize);
    mapping(uint256 => bytes3) public _pixelColours;
    mapping(uint256 => bool) public _pixelOwned;

    event PixelMinted (uint date, address to, uint256 pixelId);
    event PixelColourChanged ( address owner, bytes3 newColour, uint256 pixelId );

    constructor() ERC721("Pixels", "PIX") {}

    function mint(uint256 _pixelId) external payable {
        require(!_pixelOwned[_pixelId], "Pixel is already owned");
        require(_pixelId < _totalPixels, "Pixel out of range");
        require(msg.value >= _pixelPrice, 'No/ Insufficient fees provided');
        uint _id = _pixelId;
        _pixelOwned[_pixelId] = true;
        _pixelColours[_pixelId] = 0x777777;
        _safeMint(msg.sender, _id);
        emit PixelMinted(block.timestamp, msg.sender, _pixelId);
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
        // require(_colorHex.length <= 6, "Invalid color, needs to be in HEX format (without the #)");
        //Optional emit Event here... //NOTE: If we subscribe to the emitter we do not need to constantly query the blockchain datahbase and keep a shadowCache on a centralised database
    }

    function getPixelColour(uint256 _pixelId) public view returns (bytes3) {
        require(_pixelId < _totalPixels, "Pixel id out of range");
        if(_pixelOwned[_pixelId]) {
            return _pixelColours[_pixelId];
        } else {
            return 0x000001;
        }
    }

    // function get10Debug(uint256 offset) public view returns (bytes3[] memory) {
    //     bytes3[] memory returncodes;
    //     for (uint256 i = 0; i <10; i++) {
    //         returncodes[i] = _pixelColours[i+offset];
    //     }
    //     return returncodes;
    // }

    function isPixelOwned(uint256 _pixelId) public view returns (bool) {
        require(_pixelId < _totalPixels, "Pixel id out of range");
        return _pixelOwned[_pixelId];
    }
}