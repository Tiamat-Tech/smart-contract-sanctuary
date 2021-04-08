// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {IMerkle, IItems} from "./Interfaces.sol";
import {Items} from "./Items.sol";

contract Collections is ERC721URIStorage {

    uint256 _currentTokenId = 0;

    IItems ItemsContract;

    mapping(uint256 => mapping(bytes32 => uint256)) public detachedItems;
    mapping(uint256 => bytes32) public collectionRoots;

    event CollectionMinted(uint256 indexed tokenId);

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        ItemsContract = new Items("Collections items", "COLL-I");
    }

    function mintCollection(bytes32 root, string calldata URI) external {
        _mint(msg.sender, _currentTokenId);
        _setTokenURI(_currentTokenId, URI);

        collectionRoots[_currentTokenId] = root;

        emit CollectionMinted(_currentTokenId);

        _currentTokenId++;
    }

    function detachItem(uint256 collectionId, string calldata itemURI, bytes calldata proof) external {
        bytes32 itemHash = keccak256(abi.encodePacked(collectionId, itemURI));

        require(detachedItems[collectionId][itemHash] == 0, "The item is detached");
        require(_isApprovedOrOwner(msg.sender, collectionId), "sender is not a owner");
        require(verifyProof(itemHash, collectionRoots[collectionId], proof), "Invalid proof");

        uint256 tokenId = ItemsContract.mint(msg.sender, itemURI);
        detachedItems[collectionId][itemHash] = tokenId;
    }

    function isDetached(uint256 collectionId, string calldata itemURI) public view returns(uint256) {
        bytes32 itemHash = keccak256(abi.encodePacked(collectionId, itemURI));
        return detachedItems[collectionId][itemHash];
    }

    function verifyProof(bytes32 leaf, bytes32 root, bytes memory proof) public pure returns (bool) {
        bytes32 el;
        bytes32 h = leaf;
        for (uint256 i = 32; i <= proof.length; i += 32) {
            assembly {
                el := mload(add(proof, i))
            }

            if (h < el) {
                h = keccak256(abi.encodePacked(h, el));
            } else {
                h = keccak256(abi.encodePacked(el, h));
            }
        }
        return h == root;
    }
}