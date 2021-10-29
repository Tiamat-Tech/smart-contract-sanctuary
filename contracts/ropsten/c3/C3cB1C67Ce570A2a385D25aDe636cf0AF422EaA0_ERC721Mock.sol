//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ERC721Mock is Initializable, ERC721URIStorageUpgradeable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    function initialize() initializer public {
        __ERC721_init("ERC721Mock", "E7M");
    }

    function mint(address to, string memory metaDataUri) public returns (uint256)
    {
        _tokenIds.increment();
        uint256 newNfTId = _tokenIds.current();
        _mint(to, newNfTId);
        _setTokenURI(newNfTId, metaDataUri);

        return newNfTId;
    }
}