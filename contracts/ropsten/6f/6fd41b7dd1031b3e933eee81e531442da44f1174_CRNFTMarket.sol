// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.0;
pragma abicoder v2; // solhint-disable-line

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./mixins/FoundationTreasuryNode.sol";
import "./mixins/roles/FoundationAdminRole.sol";
import "./mixins/roles/FoundationOperatorRole.sol";
import "./mixins/NFTMarketCore.sol";
import "./mixins/SendValueWithFallbackWithdraw.sol";
import "./mixins/NFTMarketCreators.sol";
import "./mixins/NFTMarketFees.sol";
import "./mixins/NFTMarketAuction.sol";
import "./mixins/NFTMarketReserveAuction.sol";
import "./mixins/AccountMigration.sol";
import "./mixins/NFTMarketPrivateSale.sol";

/**
 * @title A market for NFTs on Foundation.
 * @dev This top level file holds no data directly to ease future upgrades.
 */
contract CRNFTMarket is
FoundationTreasuryNode,
FoundationAdminRole,
FoundationOperatorRole,
AccountMigration,
NFTMarketCore,
ReentrancyGuardUpgradeable,
NFTMarketCreators,
SendValueWithFallbackWithdraw,
NFTMarketFees,
NFTMarketAuction,
NFTMarketReserveAuction,
NFTMarketPrivateSale
{
    /**
     * @notice Called once to configure the contract after the initial deployment.
   * @dev This farms the initialize call out to inherited contracts as needed.
   */
    function initialize(address payable treasury) public initializer {
        FoundationTreasuryNode._initializeFoundationTreasuryNode(treasury);
        NFTMarketAuction._initializeNFTMarketAuction();
        NFTMarketReserveAuction._initializeNFTMarketReserveAuction();
    }

    /**
     * @notice Allows Foundation to update the market configuration.
   */
    function adminUpdateConfig(
        uint256 minPercentIncrementInBasisPoints,
        uint256 duration,
        uint256 primaryF8nFeeBasisPoints,
        uint256 secondaryF8nFeeBasisPoints,
        uint256 secondaryCreatorFeeBasisPoints
    ) public onlyFoundationAdmin {
        // It's okay to call _reinitialize multiple times, but it must be called at least once after upgrade
        _reinitialize();
        _updateReserveAuctionConfig(minPercentIncrementInBasisPoints, duration);
        _updateMarketFees(primaryF8nFeeBasisPoints, secondaryF8nFeeBasisPoints, secondaryCreatorFeeBasisPoints);
    }

    /**
     * @dev Checks who the seller for an NFT is, this will check escrow or return the current owner if not in escrow.
   * This is a no-op function required to avoid compile errors.
   */
    function _getSellerFor(address nftContract, uint256 tokenId)
    internal
    view
    virtual
    override(NFTMarketCore, NFTMarketReserveAuction)
    returns (address payable)
    {
        return super._getSellerFor(nftContract, tokenId);
    }
}