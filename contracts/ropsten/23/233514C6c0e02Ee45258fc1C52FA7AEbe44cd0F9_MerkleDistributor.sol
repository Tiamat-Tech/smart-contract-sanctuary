// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Burnable.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "./IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor, ERC1155Receiver, Ownable {
    address public immutable override token;
    bytes32 public immutable override merkleRoot;
    uint256 public immutable override startBlockNumber;
    uint256 public immutable override endBlockNumber;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(
        address tokenAddress,
        bytes32 merkleRootValue,
        uint256 startBlockNumberValue,
        uint256 endBlockNumberValue
    ) public Ownable() {
        token = tokenAddress;
        merkleRoot = merkleRootValue;
        startBlockNumber = startBlockNumberValue;
        endBlockNumber = endBlockNumberValue;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, address account, uint256 tokenType, uint256 amount, bytes32[] calldata merkleProof) external override {
        require(
            block.number >= startBlockNumber &&
            block.number <= endBlockNumber,
            'Claimable period not activated.'
        );
        require(!isClaimed(index), 'Drop already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, tokenType, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(index);
        IERC1155(token).safeTransferFrom(
            address(this),
            account,
            tokenType,
            amount,
            bytes("")
        );

        emit Claimed(index, account, tokenType, amount);
    }

    function burnAll(uint256 tokenType) external override onlyOwner() {
        require(
            block.number > endBlockNumber,
            'Claimable period activated.'
        );
        uint256 total = IERC1155(token).balanceOf(address(this), tokenType);
        require(total > 0, 'Available balance is zero.');
        ERC1155Burnable(token).burn(address(this), tokenType, total);
        emit Burnt(tokenType, total);
    }

    /*
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    )
        external
        override
        returns(bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /*
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        override
        returns(bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}