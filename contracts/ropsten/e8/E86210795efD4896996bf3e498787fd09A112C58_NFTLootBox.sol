// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTLootBox is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    IERC20 token;
    uint256 nftPrice;

    constructor() ERC721("MyNFTs", "MNFT") {
        nftPrice = 100e18;
    }

    event mintNFTLog(uint256 recipient_balance, uint256 nftPrice);

    function mintNFT(address recipient, string memory tokenURI)
        public
        onlyOwner
        returns (uint256)
    {
        emit mintNFTLog(token.balanceOf(recipient), nftPrice);
        require(token.balanceOf(recipient) > nftPrice);

        token.transferFrom(recipient, msg.sender, nftPrice);

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function setToken(address tokenAddress) public onlyOwner returns (bool) {
        require(tokenAddress != address(0x0));
        token = IERC20(tokenAddress);
        return true;
    }

    function getNftPrice() public view returns (uint256) {
        return nftPrice;
    }
}