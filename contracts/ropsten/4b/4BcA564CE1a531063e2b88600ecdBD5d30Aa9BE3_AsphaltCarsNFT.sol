// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@imtbl/imx-contracts/contracts/utils/Minting.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AsphaltCarsNFT is ERC721Enumerable, Ownable {

    string private baseURI;
    address public imx;
    bool public imxEnabled;

    constructor(
        string memory _uri,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) {
        baseURI = _uri;
        imx = _imx;
        imxEnabled = true;
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external {
        require(msg.sender == imx, "AsphaltNFT: Function can only be called by IMX");
        require(imxEnabled, "AsphaltNFT: IMX is disabled");
        require(quantity == 1, "AsphaltNFT: Invalid quantity");

        // Extracting the id from the mintingBlob
        (uint256 id, ) = Minting.split(mintingBlob);
        
        // Mint to token on L1
        _mint(user, id);
    }

    function mint(address account, uint256 id) external onlyOwner {
        _mint(account, id);
    }

    function burn(uint256 tokenId) external virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "AsphaltNFT: caller is not owner nor approved");
        _burn(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function setEnableImx(bool _isEnabled) external onlyOwner {
        imxEnabled = _isEnabled;
    }

    function setImx(address _imx) external onlyOwner {
        imx = _imx;
    }
}