// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@solidstate/contracts/token/ERC721/IERC721.sol';
import '@solidstate/contracts/token/ERC721/IERC721Receiver.sol';
import '@solidstate/contracts/utils/EnumerableSet.sol';

import '../token/IMagic.sol';

contract ERC721Farm is IERC721Receiver {
    using EnumerableSet for EnumerableSet.UintSet;

    address private immutable MAGIC;
    address private immutable ERC721_CONTRACT;
    uint256 public immutable EXPIRATION;
    uint256 private immutable RATE;

    mapping(address => EnumerableSet.UintSet) private _deposits;
    mapping(address => mapping(uint256 => uint256)) public depositBlocks;

    constructor(
        address magic,
        address erc721,
        uint256 rate,
        uint256 expiration
    ) {
        MAGIC = magic;
        ERC721_CONTRACT = erc721;
        RATE = rate;
        EXPIRATION = block.number + expiration;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function depositsOf(address account)
        external
        view
        returns (uint256[] memory)
    {
        EnumerableSet.UintSet storage depositSet = _deposits[account];
        uint256[] memory tokenIds = new uint256[](depositSet.length());

        for (uint256 i; i < depositSet.length(); i++) {
            tokenIds[i] = depositSet.at(i);
        }

        return tokenIds;
    }

    function calculateRewards(address account, uint256[] memory tokenIds)
        public
        view
        returns (uint256[] memory rewards)
    {
        rewards = new uint256[](tokenIds.length);

        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            rewards[i] =
                RATE *
                (_deposits[account].contains(tokenId) ? 1 : 0) *
                (Math.min(block.number, EXPIRATION) -
                    depositBlocks[account][tokenId]);
        }
    }

    function claimRewards(uint256[] calldata tokenIds) public {
        uint256 reward;
        uint256 block = Math.min(block.number, EXPIRATION);

        uint256[] memory rewards = calculateRewards(msg.sender, tokenIds);

        for (uint256 i; i < tokenIds.length; i++) {
            reward += rewards[i];
            depositBlocks[msg.sender][tokenIds[i]] = block;
        }

        if (reward > 0) {
            IMagic(MAGIC).mint(msg.sender, reward);
        }
    }

    function deposit(uint256[] calldata tokenIds) external {
        claimRewards(tokenIds);

        for (uint256 i; i < tokenIds.length; i++) {
            IERC721(ERC721_CONTRACT).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i],
                ''
            );

            _deposits[msg.sender].add(tokenIds[i]);
        }
    }

    function withdraw(uint256[] calldata tokenIds) external {
        claimRewards(tokenIds);

        for (uint256 i; i < tokenIds.length; i++) {
            require(
                _deposits[msg.sender].contains(tokenIds[i]),
                'ERC721Farm: token not deposited'
            );

            _deposits[msg.sender].remove(tokenIds[i]);

            IERC721(ERC721_CONTRACT).safeTransferFrom(
                address(this),
                msg.sender,
                tokenIds[i],
                ''
            );
        }
    }
}