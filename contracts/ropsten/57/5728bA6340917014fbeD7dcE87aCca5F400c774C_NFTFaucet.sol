// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { Ownable } from "../access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC721Mock {
    function mint(address to, uint256 tokenId) external;

    function totalSupply() external view returns (uint256);
}

contract NFTFaucet is Ownable {
    using SafeMath for uint256;

    mapping(address => bool) public existingCollection;
    address[] public collections;

    event NewCollection(address collection);
    event Mint(address sender, address collection, uint256 tokenId);

    function mint() external {
        uint256 length = collections.length;
        address msgSender = msg.sender;
        uint256 randCollection = random(0, length, uint256(uint160(address(msg.sender))));
        address collectionAddress = collections[randCollection];
        IERC721Mock collection = IERC721Mock(collectionAddress);
        uint256 tokenId = collection.totalSupply() + 1;
        collection.mint(msgSender, collection.totalSupply() + 1);
        emit Mint(msgSender, collectionAddress, tokenId);
    }

    function addCollection(address newCollection) external onlyOwner {
        require(!existingCollection[newCollection], "Faucet: The collection exists");
        existingCollection[newCollection] = true;
        collections.push(newCollection);
        emit NewCollection(newCollection);
    }

    function random(
        uint256 from,
        uint256 to,
        uint256 salty
    ) private view returns (uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp +
                        block.difficulty +
                        ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) +
                        block.gaslimit +
                        ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) +
                        block.number +
                        salty
                )
            )
        );
        return seed.mod(to - from) + from;
    }
}