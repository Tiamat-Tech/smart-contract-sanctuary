// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract Asset is ERC721, Mintable {

     struct Colour {
        uint8 red;
        uint8 green;
        uint8 blue;
    }

    Colour[] colours;

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}

    function getColourFromID(uint id) public view returns(uint8, uint8, uint8) {
        return (colours[id].red, colours[id].green, colours[id].blue);
    }

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        Colour memory _colour = Colour(uint8(block.timestamp), uint8(block.timestamp - 1000), uint8(block.timestamp - 5000));
        colours.push(_colour);
        uint _id = colours.length - 1;
        _mint(msg.sender, _id);
    }
}