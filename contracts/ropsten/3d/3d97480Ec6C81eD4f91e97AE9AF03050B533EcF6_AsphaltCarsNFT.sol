// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@imtbl/imx-contracts/contracts/IMintable.sol";
import "@imtbl/imx-contracts/contracts/utils/Minting.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AsphaltCarsNFT is ERC721Enumerable, Ownable, IMintable {

    string private baseURI;
    address public imx;

    constructor(
        string memory _uri,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) {
        baseURI = _uri;
        imx = _imx;
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external override {
        require(msg.sender == imx, "Function can only be called by IMX");
        require(quantity == 1, "Mintable: invalid quantity");
        (uint256 id, ) = Minting.split(mintingBlob);
        _safeMint(user, id);
    }

    function mint(address account, uint256 id, bytes memory data) public onlyOwner {
        _safeMint(account, id, data);
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