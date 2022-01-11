// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFT is ERC721Enumerable, ERC721URIStorage, Ownable {
    using ECDSA for bytes32;

    string public baseURI;
    mapping(address => bool) _minted;
    mapping(bytes32 => bool) _idMinted;

    address private _signer;

    // name: RSS3 X JIKE
    // symbol: RSS3JIKENFT
    constructor(
        address signer,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        _signer = signer;
    }

    function _hash(address _address, string memory id, string memory salt) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(_address, id, salt, address(this)));
    }

    function _verify(bytes32 hash, bytes memory sig) internal view returns (bool) {
        return (_recover(hash, sig) == _signer);
    }

    function _recover(bytes32 hash, bytes memory sig) internal pure returns (address) {
        return hash.toEthSignedMessageHash().recover(sig);
    }

    function hasMinted(address account, string memory id) public view returns (bool, bool) {
        return (_minted[account], _idMinted[keccak256(abi.encodePacked(id))]);
    }

    function mint(address to, string memory id, string memory salt, bytes memory sig) public {
        require(tx.origin == msg.sender, "Contract is now allowed to mint");
        require(_verify(_hash(to, id, salt), sig), "Invalid token");
        require(!_minted[to], "Already minted");

        bytes32 hash = keccak256(abi.encodePacked(id));
        require(!_idMinted[hash], "Id already minted");

        // mint
        _safeMint(to, totalSupply() + 1);

        // set minted flag
        _minted[to] = true;
        _idMinted[hash] = true;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setSigner(address account) public onlyOwner {
        _signer = account;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return _baseURI();
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}