//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICryptoBees.sol";
import "./Traits.sol";

contract Randomizer is Ownable {
    ICryptoBees beesContract;
    mapping(address => bool) controllers;

    event MintRevealed(address indexed owner, uint256 tokenId, uint256 _type);

    constructor() {}

    function setContracts(address _BEES) external onlyOwner {
        beesContract = ICryptoBees(_BEES);
    }

    function revealToken(uint256 blockNum) external {
        require(controllers[_msgSender()] || _msgSender() == address(beesContract), "Only controllers can reveal");

        uint256 unrevealedTokenIndex = beesContract.getUnrevealedIndex();
        if (beesContract.getUnrevealed() < blockNum && beesContract.doesExist(unrevealedTokenIndex + 1)) {
            _revealOne(unrevealedTokenIndex + 1);
        }
    }

    function revealMany(uint256 n) external onlyOwner {
        uint256 unrevealedTokenIndex = beesContract.getUnrevealedIndex();
        for (uint256 i = unrevealedTokenIndex; i < unrevealedTokenIndex + n; i++) {
            if (beesContract.doesExist(i + 1)) {
                _revealOne(i + 1);
                beesContract.pushToUnrevealedToken(block.number);
            }
        }
    }

    function _revealOne(uint256 i) private {
        uint256 seed = random(i);
        uint256 num = ((seed & 0xFFFF) % 100);
        uint8 _type = 1;
        if (num == 0) _type = 3;
        else if (num < 10) _type = 2;
        beesContract.setTokenType(i, _type);
        beesContract.setUnrevealedIndex(i);
        emit MintRevealed(_msgSender(), i, _type);
    }

    function howManyUnrevealed() public view returns (uint256) {
        uint256 unrevealedTokenIndex = beesContract.getUnrevealedIndex();
        uint256 minted = beesContract.getMinted();
        return minted - unrevealedTokenIndex;
    }

    function random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tx.origin, blockhash(block.number - 1), block.timestamp, seed)));
    }

    /**
     * enables an address to mint / burn
     * @param controller the address to enable
     */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    /**
     * disables an address from minting / burning
     * @param controller the address to disbale
     */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }
}