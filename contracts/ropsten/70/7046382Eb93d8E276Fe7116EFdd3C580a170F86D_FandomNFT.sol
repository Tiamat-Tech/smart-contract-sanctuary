//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract FandomNFT is ERC721URIStorage, ERC721Enumerable, Ownable {
    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(address => bool) private _mintableAddresses;
    bool private _isMintingFree;

    constructor() ERC721("Fandom-NFT", "FANDOMNFT") {
        _mintableAddresses[_msgSender()] = true;
        _isMintingFree = false;
    }

    function mintNFT(address recipient_, string memory tokenURI_)
    public
    returns (uint256)
    {
        if (!_isMintingFree) {
            require(_mintableAddresses[_msgSender()], "This addresss is not authorized");
        }
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient_, newItemId);
        _setTokenURI(newItemId, tokenURI_);

        return newItemId;
    }

    function setIsMintingFree(bool value_) public onlyOwner {
        _isMintingFree = value_;
    }
    function getIsMintingFree() public view returns(bool) {
        return _isMintingFree;
    }
    function setMintableAddress(address addr_, bool approved_) public onlyOwner {
        _mintableAddresses[addr_] = approved_;
    }
    function isMintableAddress(address addr_) public view returns(bool) {
        return _mintableAddresses[addr_];
    }

    function _beforeTokenTransfer(address from_, address to_, uint256 tokenId_) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from_, to_, tokenId_);
    }
    function supportsInterface(bytes4 interfaceId_) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId_);
    }
    function _burn(uint256 tokenId_) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId_);
    }
    function tokenURI(uint256 tokenId_) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId_);
    }
}