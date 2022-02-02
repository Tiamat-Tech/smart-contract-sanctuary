// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract Asset is ERC721, Mintable {
    event CallbackBurnAsset();

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }

    function burnAsset() public {
        emit CallbackBurnAsset();
    }

    function burn(uint256 tokenId) public {
        // If it isn't sent by a trusted oracle
        // a.k.a ourselves, ignore it
        require(msg.sender == owner());
        // @TODO: Check if it has been created not more than 180 days ago
        _burn(tokenId);
    }
}