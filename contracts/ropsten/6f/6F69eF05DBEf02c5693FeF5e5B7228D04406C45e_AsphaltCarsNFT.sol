// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@imtbl/imx-contracts/contracts/Mintable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AsphaltCarsNFT is ERC721Enumerable, Mintable {

    // Contract Base URI
    string private baseURI;

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}

    function mint(address account, uint256 id, bytes memory data) public onlyOwner {
        _safeMint(account, id, data);
    }

    function _mintFor(
        address to,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(to, id);
    }

    function burn(uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }
}