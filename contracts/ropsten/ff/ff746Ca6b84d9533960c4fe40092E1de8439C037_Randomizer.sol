//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICryptoBees.sol";
import "./Traits.sol";

contract Randomizer is Ownable {
    ICryptoBees beesContract;
    Traits traitsContract;
    uint256[] private unrevealedTokens;
    uint256 private unrevealedTokenIndex = 0;

    event MintRevealed(address indexed owner, uint256 tokenId, uint256 _type);

    constructor() {}

    function setContracts(address _BEES, address _TRAITS) external onlyOwner {
        beesContract = ICryptoBees(_BEES);
        traitsContract = Traits(_TRAITS);
    }

    function unrevealedTokensPush(uint256 blockNum) external {
        require(_msgSender() == address(traitsContract), "DONT CHEAT!");
        unrevealedTokens.push(blockNum);
    }

    function revealToken(uint256 blockNum) external {
        require(_msgSender() == address(traitsContract), "DONT CHEAT!");

        if (unrevealedTokens[unrevealedTokenIndex] < blockNum) {
            uint256 seed = random(unrevealedTokenIndex);
            uint256 num = ((seed & 0xFFFF) % 100);
            uint8 _type = 1;
            if (num == 0) _type = 3;
            else if (num < 10) _type = 2;
            beesContract.setTokenType(unrevealedTokenIndex + 1, _type);
            emit MintRevealed(_msgSender(), unrevealedTokenIndex + 1, _type);
            unrevealedTokenIndex++;
        }
    }

    function random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tx.origin, blockhash(block.number - 1), block.timestamp, seed)));
    }
}