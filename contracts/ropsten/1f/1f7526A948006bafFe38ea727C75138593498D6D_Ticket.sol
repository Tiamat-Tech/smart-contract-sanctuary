// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LinearlyAssigned.sol";
import "./WithContractMetaData.sol";
import "./WithIPFSMetaData.sol";

contract Ticket is ERC721Burnable, ERC721Enumerable, LinearlyAssigned, WithContractMetaData, WithIPFSMetaData {
    using SafeMath for uint256;

    event MintedTickets();

    constructor(uint256 maxElements_, string memory contractUri_, string memory cid_)
        ERC721("Ticket", "T")
        WithContractMetaData(contractUri_)
        WithIPFSMetaData(cid_)
        LinearlyAssigned(maxElements_, 0) // Max. 1k NFTs available; Start counting from 0
    {
    }

    function mintTickets() external payable onlyOwner {
        for (uint256 i = 0; i < totalSupply(); i++) {
            uint id = nextToken();
            _safeMint(_msgSender(), id);
        }
        emit MintedTickets();
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    function recoverGas() external onlyOwner {
        (payable(owner())).transfer(address(this).balance);
    }

    function totalSupply() public view override(ERC721Enumerable, WithLimitedSupply) returns (uint256) {
        return super.totalSupply();
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, WithIPFSMetaData) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _baseURI() internal view virtual override(ERC721, WithIPFSMetaData) returns (string memory) {
        return super._baseURI();
    }
}