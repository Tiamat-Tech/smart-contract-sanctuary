// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 public currentTokenId;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mintArbitrary(address _to) external {
        _mint(_to, ++currentTokenId);
    }

    function mintArbitraryBatch(address _to, uint256 _count) external {
        uint256 _currentId = currentTokenId;

        for (uint256 i = 0; i < _count; i++) {
            _mint(_to, ++_currentId);
        }

        currentTokenId = _currentId;
    }
}