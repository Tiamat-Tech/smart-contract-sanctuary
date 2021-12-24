// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Pixels is ERC721, Ownable {

    uint256 public _gridsize = 1000;
    uint256 public _totalPixels = _gridsize * _gridsize;
    uint256 public _pixelPrice = 250000000000000; // approx 1usd

    mapping(uint256 => string) public _pixelColours;
    // string[] _pixelColours = new string[](_totalPixels);
    mapping(uint256 => bool) public _pixelOwned;

    constructor() ERC721("Pixels", "PIX") {}

    function mint(uint256 _pixelId) external payable {
        require(!_pixelOwned[_pixelId], "Pixel is already owned");
        require(_pixelId < _totalPixels, "Pixel out of range");
        require(msg.value >= _pixelPrice, 'No/ Insufficient fees provided');
        // require that some money be sent
        uint _id = _pixelId;
        _pixelOwned[_pixelId] = true;
        _pixelColours[_pixelId] = "777777";
        _safeMint(msg.sender, _id);
    }

    function getBalance() public view returns(uint256){
        return address(this).balance;
    }

     function withdrawAmount(uint256 amount) external onlyOwner {
         require(amount <= getBalance(), "Insufficient funds");
         payable(msg.sender).transfer(amount);
     }

    //function change pixel colour |||ERC721.ownerOf(tokenId)
    function changePixelColor(uint256 _pixelId, string memory _colorHex) external {
        require(_pixelId < _totalPixels, "Pixel id out of range");
        require(ownerOf(_pixelId) == msg.sender, "Sender is not Pixel owner"); //TODO:is this correct?
        require(bytes(_colorHex).length <= 6, "Invalid color, needs to be in HEX format (without the #)");
        _pixelColours[_pixelId] = _colorHex;
        //Optional emit Event here...
    }

    function getPixelColour(uint256 _pixelId) public view returns (string memory) {
        require(_pixelId < _totalPixels, "Pixel id out of range");
        if(_pixelOwned[_pixelId]) {
            return _pixelColours[_pixelId];
        } else {
            return "333333";
        }
    }

    function getDebugPixelColour(uint256 _pixelId) public view returns (string memory) {
            return _pixelColours[_pixelId];
    }

    function getAll_f() public view returns (string[] memory){
        string[] memory ret = new string[](_totalPixels);
        for (uint i = 0; i < _totalPixels; i++) {
            ret[i] = _pixelColours[i];
        }
        return ret;
    }

    // function getAllPixelColours() public view returns (string[] memory) {
    //     return _pixelColours;
    // }

}