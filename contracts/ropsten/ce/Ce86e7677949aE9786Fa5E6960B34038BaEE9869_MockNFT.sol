// SPDX-License-Identifier: UNLICENSED
pragma solidity^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract MockNFT is ERC721 {
    uint256 public totalSupply;

    constructor() ERC721("MOCKNFT", "MN") {

    }

    function buy(uint256 _amount) external {
        for(uint256 i=0; i<_amount;i=i+1) {
            totalSupply = totalSupply + 1;
            _mint(msg.sender, totalSupply);
        }
    }
}