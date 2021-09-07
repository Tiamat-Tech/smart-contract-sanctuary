// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../core/NPass.sol";
import "../interfaces/IN.sol";

/**
 * @title NWar contract
 * @author Maximonee (twitter.com/maximonee_)
 * @notice This contract allows n project holders to mint a nWar NFT for their corresponding n
 */
contract NWar is NPass {
    using Strings for uint256;

    constructor(
        string memory name,
        string memory symbol,
        bool onlyNHolders,
        uint256 maxTotalSupply,
        uint16 reservedAllowance,
        uint256 priceForNHoldersInWei,
        uint256 priceForOpenMintInWei
    )
        NPass(
            name,
            symbol,
            onlyNHolders,
            maxTotalSupply,
            reservedAllowance,
            priceForNHoldersInWei,
            priceForOpenMintInWei
        ) {}

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://gateway.pinata.cloud/ipfs/Qme4eA1NdZqU6jTyFgyecHmSaYY2yGoD922GpYjwKTco5Q/";
    }

    /**
     * @notice Allow a n token holder to mint multiple tokens with an array of their n token's id
     * @param tokenIds Id to be minted
     */
    function mintMultipleWithN(uint256[] memory tokenIds) public payable virtual nonReentrant {
        uint numOfTokens = tokenIds.length;
        uint256 price = priceForNHoldersInWei;
        
        if (numOfTokens > 1) {
            price = tokenIds.length * priceForNHoldersInWei;
        }
        
        for (uint256 i = 0; i < numOfTokens; i++) {
            uint256 tokenId = tokenIds[i];

            require(
            // If no reserved allowance we respect total supply contraint
            (reservedAllowance == 0 && totalSupply() < maxTotalSupply) || reserveMinted < reservedAllowance,
            "NPass:MAX_ALLOCATION_REACHED"
            );

            require(msg.value == price, "NPass:INVALID_PRICE");
            require(n.ownerOf(tokenId) == msg.sender, "NPass:INVALID_OWNER");

            // If reserved allowance is active we track mints count
            if (reservedAllowance > 0) {
                reserveMinted++;
            }
            _safeMint(msg.sender, tokenId);
        }
    }
}