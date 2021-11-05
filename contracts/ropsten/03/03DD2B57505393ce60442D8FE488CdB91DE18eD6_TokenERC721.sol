// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TokenERC721 is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 decimal = 10**18;

    constructor() ERC721("TokenERC721", "TK721") {}

    function mint(address token, uint256 amount) public {
        require(
            ERC20(token).transferFrom(tx.origin, address(this), amount),
            "transferFrom failed"
        );
        uint256 loop = (amount / decimal) / 100;
        for (uint256 i = 0; i < loop; i++) {
            _tokenIds.increment();
            uint256 id = _tokenIds.current();
            _safeMint(tx.origin, id);
        }
    }

    function getBalances(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }
}