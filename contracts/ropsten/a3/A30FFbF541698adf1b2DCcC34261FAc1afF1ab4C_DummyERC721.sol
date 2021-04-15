//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DummyERC721 is ERC721("DummyNFT", "DNFT"), Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    function mint(address tokenHolder) public onlyOwner returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(tokenHolder, newItemId);
        return newItemId;
    }
}