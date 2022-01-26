// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "./libraries/IPFS.sol";
import "./libraries/LiteralStrings.sol";

contract Collectibles is
    Initializable,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    ERC721PausableUpgradeable
{
    using StringsUpgradeable for uint256;
    using IPFS for bytes32;
    using IPFS for bytes;
    using LiteralStrings for bytes;

    mapping(uint256 => bytes32) public ipfsHashMemory;

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __Ownable_init_unchained();
        transferOwnership(_owner);
        __ERC721_init_unchained(_name, _symbol);
    }

    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }

    function _setIpfsHash(uint256 _tokenId, bytes32 _ipfsHash) internal {
        ipfsHashMemory[_tokenId] = _ipfsHash;
    }

    function setIpfsHash(uint256 _tokenId, bytes32 _ipfsHash) public onlyOwner {
        _setIpfsHash(_tokenId, _ipfsHash);
    }

    function setIpfsHash(uint256[] memory _tokenIdList, bytes32[] memory _ipfsHashList) public onlyOwner {
        require(_tokenIdList.length == _ipfsHashList.length, "input length must be same");
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            _setIpfsHash(_tokenIdList[i], _ipfsHashList[i]);
        }
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "token must exist");
        if (ipfsHashMemory[_tokenId] != "") {
            return string(ipfsHashMemory[_tokenId].addSha256FunctionCodePrefix().toBase58().addIpfsBaseUrlPrefix());
        } else {
            return super.tokenURI(_tokenId);
        }
    }

    function mint(address _to, uint256 _tokenId) public onlyOwner {
        _mint(_to, _tokenId);
    }

    function mint(address _to, uint256 _tokenId, bytes32 _ipfsHash) public onlyOwner {
        _mint(_to, _tokenId);
        _setIpfsHash(_tokenId, _ipfsHash);
    }

    function mint(address[] memory _toList, uint256[] memory _tokenIdList) public onlyOwner {
        require(_toList.length == _tokenIdList.length, "input length must be same");
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            _mint(_toList[i], _tokenIdList[i]);
        }
    }

    function mint(address[] memory _toList, uint256[] memory _tokenIdList, bytes32[] memory _ipfsHashList) public onlyOwner {
        require(_toList.length == _tokenIdList.length, "input length must be same");
        require(_tokenIdList.length == _ipfsHashList.length, "input length must be same");
        for (uint256 i = 0; i < _tokenIdList.length; i++) {
            _mint(_toList[i], _tokenIdList[i]);
            _setIpfsHash(_tokenIdList[i], _ipfsHashList[i]);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Upgradeable, ERC721PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 _tokenId) internal virtual override(ERC721Upgradeable) {
        super._burn(_tokenId);
        if (ipfsHashMemory[_tokenId] != "") {
            delete ipfsHashMemory[_tokenId];
        }
    }
}