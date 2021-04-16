pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Itti_NFT is ERC1155 {

    uint256 public constant SEG_TAO = 0;

    constructor() ERC1155("https://game.example/api/item/{id}.json") {

        _mint(msg.sender, SEG_TAO, 1, "");
        _setTokenURI(SEG_TAO, "https://lh6.googleusercontent.com/_LqTRxTc-kx8/TZhkVL4pNhI/AAAAAAAAAGQ/lncgG5Jicos/%E0%B8%A1%E0%B9%89%E0%B8%B2%E0%B9%80%E0%B8%8B%E0%B9%87%E0%B8%81%E0%B9%80%E0%B8%97%E0%B8%B2.jpg");

    }

    mapping(uint256 => string) private _tokenURIs;

    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        _tokenURIs[tokenId] = uri;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return _tokenURIs[tokenId];
    }

}