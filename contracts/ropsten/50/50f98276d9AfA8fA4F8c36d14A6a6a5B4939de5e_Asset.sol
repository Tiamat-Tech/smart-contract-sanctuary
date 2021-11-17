// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./Mintable.sol";

contract Asset is ERC721Enumerable, Mintable {
    string private _baseURIExtended;
    string private _contractURIExtended;

    constructor(
        address _owner,
        string memory baseURI_,
        string memory contractURI_,
        address _imx
    ) ERC721("Test IMX", "TIMX") Mintable(_owner, _imx) {
        _baseURIExtended = baseURI_;
        _contractURIExtended = contractURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIExtended;
    }

    function baseTokenURI() public view returns (string memory) {
        return _baseURIExtended;
    }

    function contractURI() public view returns (string memory) {
        return _contractURIExtended;
    }

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }

    function setBaseTokenURI(string memory uri) public onlyOwner {
        _baseURIExtended = uri;
    }

    function setContractURI(string memory uri) public onlyOwner {
        _contractURIExtended = uri;
    }
}