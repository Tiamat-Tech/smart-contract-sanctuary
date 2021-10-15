// contracts/UPFT.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UPFT is Initializable, ERC721Upgradeable, UUPSUpgradeable, OwnableUpgradeable {

    uint256 claimPrice;
    uint256 claimed;
    uint256 maxSupply;

    function initialize() initializer public {
        __ERC721_init("UPFT", "UPFT");
        __Ownable_init();

        claimPrice = 0.01 ether;
        maxSupply = 100;

        for (uint256 index = 0; index < 50; index++) {
            _safeMint(msg.sender, index);   
            claimed++;
        }
    }

    function claim (uint256 _numTokens) external payable {
        require (msg.value >= claimPrice, "Insufficient value sent");
        require (claimed + _numTokens <= maxSupply, "More than max");

        for (uint256 index = claimed; index < claimed + _numTokens; index++) {
            if (index <= maxSupply) {
                _safeMint(msg.sender, index);   
                claimed++;
            }
        } 
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}
}