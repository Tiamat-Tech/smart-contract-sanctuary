// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./tokens/ERC1155Upgradeable.sol";

contract BMIUtilityNFT is OwnableUpgradeable, ERC1155Upgradeable {
    uint256 private constant NFT_TYPES_COUNT = 4;
    uint256 private constant LEADERBOARD_SIZE = 10;

    function __BMIUtilityNFT_init() external initializer {
        __Ownable_init();
        __ERC1155_init("");
    }

    /// @dev the output URI will be: "https://token-cdn-domain/<tokenId>.json"
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(0), Strings.toString(tokenId), ".json"));
    }

    /// @dev this is a correct URI: "https://token-cdn-domain/"
    function setBaseURI(string calldata newURI) external onlyOwner {
        _setURI(newURI);
    }

    /// @dev if we want to use external ERC1155, then we need to send
    /// required NFTs directly to LM contract + change NFTs' indices there
    function mintNFTsForLM(address _liquidiyMiningAddr) external onlyOwner {
        uint256[] memory _ids = new uint256[](NFT_TYPES_COUNT);
        uint256[] memory _amounts = new uint256[](NFT_TYPES_COUNT);

        _ids[0] = 1;
        _amounts[0] = 5;

        _ids[1] = 2;
        _amounts[1] = 1 * LEADERBOARD_SIZE;

        _ids[2] = 3;
        _amounts[2] = 3 * LEADERBOARD_SIZE;

        _ids[3] = 4;
        _amounts[3] = 6 * LEADERBOARD_SIZE;

        _mintBatch(_liquidiyMiningAddr, _ids, _amounts, "");
    }
}