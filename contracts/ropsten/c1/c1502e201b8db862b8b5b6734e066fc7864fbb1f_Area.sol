// STATUS: BETA
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.6; // code below expects that integer overflows will revert
import "./AreaNFT.sol";
import "./RandomDropVending.sol";
import "./Utilities/PlusCodes.sol";
import "./Vendor/openzeppelin-contracts-3dadd40034961d5ca75fa209a4188b01d7129501/access/Ownable.sol";

/// @title  Area main contract, 🌐 the earth on the blockchain, 📌 geolocation NFTs
/// @notice This contract is responsible for initial allocation and non-fungible tokens.
///         ⚠️ Bad things will happen if the reveals do not happen a sufficient amount for more than ~60 minutes.
/// @author William Entriken
contract Area is Ownable, AreaNFT, RandomDropVending {
    /// @param inventorySize      Inventory for code length 4 tokens for sale (normally 43,200)
    /// @param teamAllocation     How many set aside for team
    /// @param pricePerPack       The cost in Wei for each pack
    /// @param packSize           How many drops can be purchased at a time
    /// @param name               ERC721 contract name
    /// @param symbol             ERC721 symbol name
    /// @param baseURI            Prefix for all token URIs
    /// @param priceToSplit       Value (in Wei) required to split Area tokens
    constructor(
        uint256 inventorySize,
        uint256 teamAllocation,
        uint256 pricePerPack,
        uint32 packSize,
        string memory name,
        string memory symbol,
        string memory baseURI,
        uint256 priceToSplit
    )
        RandomDropVending(inventorySize, teamAllocation, pricePerPack, packSize)
        AreaNFT(name, symbol, baseURI, priceToSplit)
    {
    }

    /// @notice Start the sale
    function beginSale() onlyOwner external {
        _beginSale();
    }

    /// @notice In case of emergency, the number of allocations set aside for the team can be adjusted
    /// @param teamAllocation The new allocation amount
    function setTeamAllocation(uint256 teamAllocation) onlyOwner external {
        _setTeamAllocation(teamAllocation);
    }

    /// @notice A quantity of Area tokens that were committed by anybody and are now mature are revealed
    /// @param  revealsLeft Up to how many reveals will occur
    function reveal(uint32 revealsLeft) onlyOwner external {
        RandomDropVending._reveal(revealsLeft);
    }

    /// @notice Takes some of the code length 4 codes that are not near the poles and assigns them. Team is unable to
    ///         take tokens until all other tokens are allocated from sale.
    /// @param  recipient The account that is assigned the tokens
    /// @param  quantity  How many to assign
    function mintTeamAllocation(address recipient, uint256 quantity) onlyOwner external {
        RandomDropVending._takeTeamAllocation(recipient, quantity);
    }

    /// @notice Takes some of the code length 2 codes that are near the poles and assigns them. Team is unable to take
    ///         tokens until all other tokens are allocated from sale.
    /// @param  recipient    The account that is assigned the tokens
    /// @param  indexFromOne a number in the closed range [1, 54]
    function mintWaterAndIceReserve(address recipient, uint256 indexFromOne) onlyOwner external {
        require(RandomDropVending._inventoryForSale() == 0, "Cannot take during sale");
        uint256 tokenId = PlusCodes.getNthCodeLength2CodeNearPoles(indexFromOne);
        AreaNFT._mint(recipient, tokenId);
    }

    /// @notice Pay the bills
    function withdrawBalance() onlyOwner external {
        payable(msg.sender).transfer(address(this).balance);        
    }

    /// @inheritdoc RandomDropVending
    function _revealCallback(address recipient, uint256 allocation) override(RandomDropVending) internal {
        uint256 tokenId = PlusCodes.getNthCodeLength4CodeNotNearPoles(allocation);
        AreaNFT._mint(recipient, tokenId);
    }
}