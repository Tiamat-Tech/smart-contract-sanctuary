pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract Color is ERC721PresetMinterPauserAutoId{

    string[] public colors;
    uint256 num_colors;

    //how to check uniticity of color?
    mapping(string => bool) _colorExists;
    constructor (string memory name, string memory symbol,string memory baseTokenURI) ERC721PresetMinterPauserAutoId (name,symbol,baseTokenURI){
        num_colors = 0;
        
    }
    
    function my_mint(string memory color) public{
        require(!_colorExists[color]);
        colors.push(color);
        _safeMint(msg.sender, num_colors);
        num_colors = num_colors + 1;
        _colorExists[color] = true;
        
    }
    function getcolors() public view returns (string[] memory){
        return colors;
    }
    function getsinglecolor(uint indice) public view returns (string memory){
        return colors[indice];
    }
    function test(string memory input) public pure returns (string memory) {
        return input;
    }

    
}