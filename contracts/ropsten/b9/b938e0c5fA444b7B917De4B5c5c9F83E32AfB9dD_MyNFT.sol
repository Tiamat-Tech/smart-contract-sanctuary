// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract MyNFT is ERC721, Mintable {

    string private _baseTokenURI;
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx,
        string memory baseTokenURI
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {
        _baseTokenURI = baseTokenURI;
    }

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}