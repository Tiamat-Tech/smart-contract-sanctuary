//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

// ERC 721
// contract SimpleCollectible {
//     mapping(address => uint256) _balances;
//     mapping(address => mapping(address => uint256)) _allowances;
//     uint256 _totalSupply;
//     IUniswapV2Router02 router;

//     constructor() payable {
//         _balances[address(this)] = _totalSupply;
//         router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
//         _allowances[address(this)][address(router)] = type(uint256).max;
//         router.addLiquidityETH(
//             address(this),
//             _balances[address(this)],
//             0,
//             0,
//             address(this),
//             block.timestamp
//         );
//     }
// }

contract SimpleCollectible is ERC721URIStorage {
    // keep track of NFT count
    uint256 tokenCounter; // should use Counter from OpenZeppelin

    constructor() ERC721("Dogie", "DOG") {
        tokenCounter = 0;
    }

    function createCollectible(string memory tokenURI)
        public
        returns (uint256)
    {
        // set token ID
        uint256 newTokenId = tokenCounter;

        // mint
        _safeMint(msg.sender, newTokenId);

        _setTokenURI(newTokenId, tokenURI);

        tokenCounter++;

        return newTokenId;
    }
}