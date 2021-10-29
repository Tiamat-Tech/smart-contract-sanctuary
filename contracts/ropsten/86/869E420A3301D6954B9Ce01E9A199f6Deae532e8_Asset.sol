// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract Asset is ERC721, Mintable {
    mapping(uint256 => string) nftDescription;
    mapping(uint256 => string) metadataURL;

    event Minted (address user, uint256 id, string description, string link);

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory mintingBlob
    ) internal override {
        
         (string memory description, string memory link) = Minting.deserializeMintingBlob(mintingBlob);
         nftDescription[id] = description;
         metadataURL[id] = link;
         _safeMint(user, id);

        emit Minted(user, id, nftDescription[id], metadataURL[id]);
    }
}