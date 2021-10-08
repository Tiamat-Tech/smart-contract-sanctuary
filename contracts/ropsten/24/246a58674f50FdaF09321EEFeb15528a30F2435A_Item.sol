// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Item
/// @notice NFT contract for Items
contract Item is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds; // tokenId counter to ensure unique tokenIds
    address public speerContract;

    constructor() ERC721("Item NFT", "ITEM") {}

    /// @notice Set SpeerContract
    /// @notice Only callable by Owner
    /// @param _speerContract - Address for the SpeerContract
    function setSpeer(address _speerContract) external onlyOwner {
        speerContract = _speerContract;
    }

    /// @notice Create a new Item (Mint NFT)
    /// @param to - Initial holder of the Item
    /// @param uri - URI for the Item Metadata
    function createItem(address to, string memory uri)
        external
        onlySpeer
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(to, newTokenId);
        _setTokenURI(newTokenId, uri);
        return newTokenId;
    }

    /// @notice Burn Item
    /// @param tokenId - Token ID of Item
    function burn(uint256 tokenId) external onlySpeer {
        _burn(tokenId);
    }

    /// @notice reverts if caller is not the SpeerTech contract
    modifier onlySpeer() {
        require(msg.sender == speerContract, "Unauthorized");
        _;
    }
}