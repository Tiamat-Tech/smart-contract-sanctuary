// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Color is ERC721Enumerable, Ownable {
    string[] public colors;
    mapping(string => bool) _colorExists;
    mapping(uint256 => mapping(uint256 => bool)) _bool_grid;
    mapping(uint256 => mapping(uint256 => string)) _color_grid;
    mapping(string => bool) _approved;
    mapping(address => bool) _mods;

    modifier onlyMods() {
        require(_mods[_msgSender()], "Mods: caller is not a mod");
        _;
    }

    function addMod(address _newAddress) public onlyOwner {
        _mods[_newAddress] = true;
    }

    function isMod(address _modAddress) public view returns (bool) {
        return _mods[_modAddress];
    }

    constructor() ERC721("Color", "COLOR") {}

    function mint(string memory _color) public {
        require(!_colorExists[_color], "color already taken");
        require(bytes(_color).length <= 7, "not a valid color");
        colors.push(_color);
        uint _id = colors.length - 1;
        _colorExists[_color] = true;
        _approved[_color] = false;
        // _grid[0][1] = true;
        _safeMint(msg.sender, _id);
    }

    // function approveColor(string _color) public onlyMods {

    // }

    // function getGrid(uint256 _xcoord, uint256 _ycoord) public view returns (bool) {
    //     return _grid[_xcoord][_ycoord];
    // }
}