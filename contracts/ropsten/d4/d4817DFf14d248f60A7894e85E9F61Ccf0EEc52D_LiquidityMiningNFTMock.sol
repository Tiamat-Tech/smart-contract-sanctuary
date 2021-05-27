// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract LiquidityMiningNFTMock is Ownable, ERC1155 {
    uint256 private constant NFT_TYPES_COUNT = 4;
    uint256 private constant LEADERBOARD_SIZE = 10;

    constructor() ERC1155("") {}

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