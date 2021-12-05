// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./EmblemDremKnobs.sol";

contract EmblemDrem is EmblemDremKnobs, ERC20 {
    /// @dev Keep track of season claims
    mapping(uint32 => mapping(uint256 => bool)) internal packIdToCardIdClaimed;

    constructor(address _nftContract)
        EmblemDremKnobs(_nftContract)
        ERC20("Dark Emblem Coin", "DREM")
    {}

    /// @dev CFO can mint new $DREM
    function mint(address to, uint256 amount) external onlyCFO whenNotPaused {
        require(msg.sender == cfoAddress);
        require(to != address(0));
        require(amount > 0);
        _mint(to, amount);
    }

    function _estimateClaimAmount() internal view returns (uint256) {
        uint256 claimed = 0;

        // Get the number of cards owned by the user
        uint256 numCards = nonFungibleContract.balanceOf(msg.sender);

        // Get the current season
        uint32 packId = nonFungibleContract.currentPackId();

        // Cap for-loop to 10000 iterations
        uint256 maxIterations = Math.min(numCards, 10000);

        // For each card, get card id
        for (uint256 i = 0; i < maxIterations; i++) {
            //slither-disable-next-line calls-loop -- We have a maxIterations cap, and we own the contract
            uint256 cardId = nonFungibleContract.tokenOfOwnerByIndex(
                msg.sender,
                i
            );

            // Have we already flagged for this card?
            if (!packIdToCardIdClaimed[packId][cardId]) {
                claimed++;
            }
        }

        // For every N cards a holder has, give them $DREM
        uint256 amount = claimed / rewardThreshold;

        return amount;
    }

    function _claimAmount() internal returns (uint256) {
        uint256 claimed = 0;

        // Get the number of cards owned by the user
        uint256 numCards = nonFungibleContract.balanceOf(msg.sender);

        // Get the current season
        uint32 packId = nonFungibleContract.currentPackId();

        // Cap for-loop to 10000 iterations
        uint256 maxIterations = Math.min(numCards, 10000);

        // For each card, get card id
        for (uint256 i = 0; i < maxIterations; i++) {
            //slither-disable-next-line calls-loop -- We have a maxIterations cap, and we own the contract
            uint256 cardId = nonFungibleContract.tokenOfOwnerByIndex(
                msg.sender,
                i
            );

            // Have we already flagged for this card?
            if (!packIdToCardIdClaimed[packId][cardId]) {
                claimed++;
            }
            packIdToCardIdClaimed[packId][cardId] = true;
        }

        // For every N cards a holder has, give them $DREM
        uint256 amount = claimed / rewardThreshold;

        return amount;
    }

    function previewClaim() external view returns (uint256) {
        uint256 amount = _estimateClaimAmount();
        return amount;
    }

    function claim() external whenNotPaused {
        uint256 amount = _claimAmount();

        if (amount > 0) {
            _mint(msg.sender, amount);
        }
    }

    /// @dev override implementation to always allow nonFungibleContract to transfer
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (msg.sender != address(nonFungibleContract)) {
            return super.transferFrom(sender, recipient, amount);
        } else {
            // Only worry about allowances for other addresses
            _transfer(sender, recipient, amount);

            return true;
        }
    }
}