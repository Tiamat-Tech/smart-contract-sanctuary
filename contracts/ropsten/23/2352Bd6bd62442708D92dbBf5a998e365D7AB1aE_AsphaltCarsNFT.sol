// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@imtbl/imx-contracts/contracts/Mintable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AsphaltCarsNFT is ERC721Enumerable, Ownable, IMintable {

    // Contract Base URI
    string private baseURI;

    // IMX Contract
    address public imx;

    event AssetMinted(address indexed to, uint256 id);

    constructor(
        string memory _uri,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) {
        baseURI = _uri;
        imx = _imx;
    }

    modifier onlyOwnerOrIMX() {
        require(msg.sender == imx || msg.sender == owner(), "Function can only be called by owner or IMX");
        _;
    }

    function mint(address account, uint256 id, bytes memory data) public onlyOwner {
        _safeMint(account, id, data);
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external override onlyOwnerOrIMX {
        require(quantity == 1, "Mintable: invalid quantity");
        (uint256 id, ) = Minting.split(mintingBlob);
        _safeMint(user, id);
        emit AssetMinted(user, id);
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