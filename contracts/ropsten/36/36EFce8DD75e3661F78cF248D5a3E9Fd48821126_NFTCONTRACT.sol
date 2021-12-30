pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract NFTCONTRACT is ERC721PresetMinterPauserAutoId {

    constructor() ERC721PresetMinterPauserAutoId("NFTCONTRACT", "AIS", "https://aisthisi.art/metadata/") {}

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
       return string(abi.encodePacked(super.tokenURI(tokenId),".json"));
    }
}