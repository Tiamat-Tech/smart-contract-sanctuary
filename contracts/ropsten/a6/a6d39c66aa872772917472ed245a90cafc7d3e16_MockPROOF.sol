// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9 <0.9.0;

import "@divergencetech/ethier/contracts/erc721/ERC721Common.sol";
import "@divergencetech/ethier/contracts/utils/Monotonic.sol";

contract MockPROOF is ERC721Common {
    using Monotonic for Monotonic.Increaser;

    constructor() ERC721Common("", "") {}

    Monotonic.Increaser public totalSupply;

    function mint(uint256 n) external {
        uint256 nextTokenId = totalSupply.current();
        uint256 end = nextTokenId + n;
        for (; nextTokenId < end; nextTokenId++) {
            _mint(msg.sender, nextTokenId);
        }
        totalSupply.add(n);
    }
}