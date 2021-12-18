//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract Rug is ERC721Enumerable, ERC721URIStorage, Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter internal _tokenIds;

    uint256 public constant tokenPrice = 0.042 ether;
    uint256 public maxSupply = 4200;

    constructor() ERC721("Rug On Chain", "RUG") { }

    // requirements for inheriting both ERC721Enumerable & ERC721URIStorage
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal 
        override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage)
        returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view
        override(ERC721, ERC721Enumerable)
        returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev return all token ids own by specific address.
     *
     * Requirements:
     *
     * - `_owner` must exist.
     *
     * returns array of token ids.
     */
    function tokensOf(address _owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        if(tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;

            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }

            return result;
        }
    }

    function mintedAmount() public view returns(uint) {
        return _tokenIds.current();
    }

    function rugPull(string[] calldata _uris) public whenNotPaused payable {
        uint256 newItemId = _tokenIds.current();
        uint256 count = _uris.length;

        require(newItemId + count <= maxSupply, "Mint amount exceeds the max supply");
        require(tokenPrice <= msg.value, "The Account balance is not enough");

        uint i = 0;
        while (i < count) {
            _tokenIds.increment();
            newItemId = _tokenIds.current();

            _safeMint(msg.sender, newItemId);
            _setTokenURI(newItemId, _uris[i]);
            i += 1;
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "You are not the owner of token");
        _burn(tokenId);
    }

}