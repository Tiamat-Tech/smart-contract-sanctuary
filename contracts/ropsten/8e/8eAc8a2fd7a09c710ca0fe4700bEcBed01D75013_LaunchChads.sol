// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@imtbl/imx-contracts/contracts/IMintable.sol';
import '@imtbl/imx-contracts/contracts/Mintable.sol';

contract LaunchChads is ERC721, Ownable, IMintable{
    // Events
    event AssetMinted(address to, uint256 id, bytes blueprint);

    // Addresses
    address public imx;

    // String
    string baseURI;

    // Mappings
    mapping(uint256 => string) private _tokenURI;
    mapping(uint256 => bytes) public blueprints;

    modifier onlyIMX() {
        require(msg.sender == imx, "LaunchChads: Function can only be called by IMX");
        _;
    }

    constructor(address _imx) ERC721("LaunchChads", "LC") {
        require(_imx != address(0x0), 'LaunchChads: Treasury address cannot be the 0x0 address');
        imx = _imx;
    }

    function mintFor(address user, uint256 quantity, bytes calldata mintingBlob) external override onlyIMX {
        require(quantity == 1, "LaunchChads: invalid quantity");
        (uint256 id, bytes memory blueprint) = Minting.split(mintingBlob);
        _mintFor(user, id);
        blueprints[id] = blueprint;
        emit AssetMinted(user, id, blueprint);
    }

    function _mintFor(address to, uint256 id) internal virtual {
        require(!_exists(id), "LaunchChads: Token ID Has Been Used");
        _mint(to, id);
    }

    function setBaseURI(string memory _URI) external onlyOwner{
        baseURI = _URI;
    }

    /** OVERRIDES */
    function _baseURI() internal view override virtual returns (string memory) {
        return baseURI;
    }
}