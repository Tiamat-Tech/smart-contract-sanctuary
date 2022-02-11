// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTAirdrop is Ownable {
    /// @notice Address of the airdrop executor
    address public admin;

    /// @notice On contract deployment
    constructor(address _admin) {
        admin = _admin;
    }

    /// @notice Change admin address
    /// @param newAdmin - New admin address
    function setAdmin(address newAdmin) external onlyOwner {
        admin = newAdmin;
    }

    /**
     * @dev Airdrop function from external wallet by two lists with ids and recipients.
     * @param from - Admin wallet with NFTs
     * @param nftAddress - Address of NFT token to airdrop
     * @param ids - Token IDs
     * @param recipients - Array of airdrop recipients
     */
    function airdrop(
        address from,
        address nftAddress,
        uint256[] calldata ids,
        address[] calldata recipients
    ) external {
        require(msg.sender == admin, "Admin only");
        require(from != address(0), "From address is zero");
        require(nftAddress != address(0), "NFT address is zero");
        require(ids.length == recipients.length, "Wrong input arrays");
        require(ids.length > 0, "empty arrays");
        for (uint32 i = 0; i < ids.length; i++) {
            IERC721(nftAddress).safeTransferFrom(from, recipients[i], ids[i]);
        }
    }
}