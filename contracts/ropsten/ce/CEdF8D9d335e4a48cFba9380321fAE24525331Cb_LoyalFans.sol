//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract LoyalFans is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bool public blocked = false;
    address public lockerAddress;
    mapping (uint => uint) public tokenLockedUntilTimestamp;

    constructor() public ERC721("LoyalFans", "LYF") {}

    function mintNFT(address recipient, string memory tokenURI)
    public onlyOwner
    returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function setLockerAddress(address _lockerAddress) public onlyOwner{
        lockerAddress = _lockerAddress;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if (from == lockerAddress) {
            tokenLockedUntilTimestamp[tokenId] = block.timestamp + 300;
        }
        require(blocked);
    }
}