//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Names is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address payable private _owner;

    constructor() public ERC721("Names", "NAME") {}

    uint256 MAX_SUPPLY = 10;

    function mintNFT(address recipient)
        public
        returns (uint256)
    {
        require(_tokenIds.current() < MAX_SUPPLY);
        _tokenIds.increment();

        string memory newItemIdString = Strings.toString(_tokenIds.current());
        string memory fileExtendo = string(abi.encodePacked(newItemIdString, ".json"));
        string memory link = string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/QmdXSfCCrG5c5bkv6kmT6txS3J4u33C8ddg6fpou1LicM8/name-", fileExtendo));

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, link);

        return newItemId;
    }
}