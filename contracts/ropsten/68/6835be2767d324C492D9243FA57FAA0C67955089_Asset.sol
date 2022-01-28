// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract Asset is ERC721, Mintable {
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {

        
        _name = "CommuneCash NFT";
        _symbol = "COMCASH";
    }

    function _mintFor(
        address _to,
        uint256 _tokenId,
        bytes memory _uri
    ) internal override {
        _safeMint(_to, _tokenId,_uri);
    }

   

}