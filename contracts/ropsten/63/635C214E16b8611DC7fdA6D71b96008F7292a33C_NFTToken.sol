pragma solidity ^0.8.4;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

import "hardhat/console.sol";

contract NFTToken is ERC721,Ownable{

    struct Color{
        uint8 r;
        uint8 g;
        uint8 b;
    }

    mapping(uint256 => Color) private _colors;

    
    uint256 private totalSupply;

    constructor (string memory name_, string memory symbol_) ERC721(name_,symbol_){}

    function color(uint256 tokenId) public view returns (uint8,uint8,uint8){
        Color memory _color = _colors[tokenId];
        return (_color.r,_color.g,_color.b);
    }

    function _baseURI() internal pure override returns (string memory){
        return "https://www.color-hex.com/color/";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        Color memory c = _colors[tokenId];
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, uint8tohexstr(c.r),uint8tohexstr(c.g),uint8tohexstr(c.b))) : "";
    }

    //helper functions to convert bytes to hexadecimal strings
     function uint8tohexchar(uint8 i) public pure returns (uint8) {
        return (i > 9) ?
            (i + 87) : // ascii a-f
            (i + 48); // ascii 0-9
    }

     function uint8tohexstr(uint8 i) public pure returns (string memory) {
        bytes memory o = new bytes(2);
        uint8 mask = 0x0f;
        o[1] = bytes1(uint8tohexchar(uint8(i & mask)));
        i = i >> 4;
        o[0] = bytes1(uint8tohexchar(uint8(i & mask)));
        return string(o);
    }
    
    //@dev derives a RGB color from the hash of msg.sender, block.coinbase and the tokenId
    // block.coinbase is used so that the color is picked with more randomness since block.coinbase is not known prior to block being mined
    function mint() public {
        bytes32 computedHash= keccak256(abi.encodePacked(msg.sender,block.coinbase,totalSupply));
        uint8 r= uint8(bytes1(computedHash));
        uint8 g= uint8(bytes1(computedHash << 8));
        uint8 b= uint8(bytes1(computedHash << 16));
        _mint(msg.sender,totalSupply);
        _colors[totalSupply]=Color(r,g,b);
        totalSupply+=1;
    }
}