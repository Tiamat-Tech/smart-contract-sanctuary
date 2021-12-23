pragma solidity 0.7.5;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";

contract ERC721Token is ERC721("Test", "Test") {
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}