//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICryptoBees.sol";

contract Randomizer is Ownable {
    ICryptoBees beesContract;
    uint256[] private unrevealedTokens;
    uint256 private unrevealedTokenIndex = 1;

    event MintRevealed(address indexed owner, uint256 tokenId, uint256 _type);

    constructor() {}

    function setBeesContract(address _BEES_CONTRACT) external onlyOwner {
        beesContract = ICryptoBees(_BEES_CONTRACT);
    }

    function unrevealedTokensPush(uint256 blockNum) external {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");
        unrevealedTokens.push(blockNum);
    }

    function revealToken(uint256 blockNum) external {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");

        if (unrevealedTokens[unrevealedTokenIndex] < blockNum) {
            uint256 seed = random(unrevealedTokenIndex);
            uint256 num = ((seed & 0xFFFF) % 100);
            uint8 _type = 1;
            if (num == 0) _type = 3;
            else if (num < 10) _type = 2;
            beesContract.setTokenType(unrevealedTokenIndex, _type);
            emit MintRevealed(_msgSender(), unrevealedTokenIndex, _type);
            unrevealedTokenIndex++;
        }
    }

    function random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tx.origin, blockhash(block.number - 1), block.timestamp, seed)));
    }
}