/// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract MockNFT is ERC721 {

    uint256 private _tokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}
    
    /// mints NFT to `to`
    function mint(address to) external {
        _mint(to, _tokenId);
        _tokenId++;
    }

    /// mints a specified `amount` of NFTs to `to`
    function mintMultiple(address to, uint8 amount) external {
        require(amount <= 128, "too many");
        for (uint256 i = 0; i <= amount; i++) {
            _mint(to, _tokenId);
            _tokenId++;
        }
    }

}