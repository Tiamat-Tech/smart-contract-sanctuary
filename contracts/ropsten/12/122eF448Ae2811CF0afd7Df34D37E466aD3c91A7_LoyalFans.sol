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

    address public lockerAddress;
    uint256 public lockDuration;
    mapping (uint => uint) public tokenLockedUntilTimestamp;

    constructor() public ERC721("LoyalFans", "LYF") {}

    function mintNFT(address recipient, string memory tokenURI) public onlyOwner returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function setLockingParameters(address _lockerAddress, uint256 _lockDuration) public onlyOwner{
        lockerAddress = _lockerAddress;
        lockDuration = _lockDuration;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        require(tokenLockedUntilTimestamp[tokenId] < block.timestamp || to == lockerAddress, "Token is locked");
        if (from == lockerAddress) {
            tokenLockedUntilTimestamp[tokenId] = block.timestamp + lockDuration;
        }
    }

    function reclaimToken(address from, uint256 tokenId) public {
        require(msg.sender == lockerAddress, "Only minter can reclaim");
        require(tokenLockedUntilTimestamp[tokenId] > block.timestamp, "Token is not locked");
        _transfer(from,lockerAddress,tokenId);
    }


}