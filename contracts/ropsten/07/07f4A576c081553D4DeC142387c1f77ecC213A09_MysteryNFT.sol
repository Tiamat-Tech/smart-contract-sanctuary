// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "hardhat/console.sol";

contract MysteryNFT is ERC721HolderUpgradeable, ERC1155HolderUpgradeable, OwnableUpgradeable {
    // using SafeMathUpgradeable for uint256;

    struct NftConfig {
        address nftAddr;
        uint256 nftType;
    }
    
    NftConfig public nftConfig;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Ownable_init();
    }

    function setNftConfig(address _addr, uint256 _type) public onlyOwner {
        nftConfig = NftConfig(_addr, _type);
    }

    function onERC1155Received(
        address _operator, address _from, uint256 _id, uint256 _amount, bytes memory _data
    ) public virtual override returns (bytes4) {
        console.log("Received");
        console.log(_operator);
        console.log(_from);
        console.log(_id);
        console.log(_amount);
        return this.onERC1155Received.selector;
    }

}