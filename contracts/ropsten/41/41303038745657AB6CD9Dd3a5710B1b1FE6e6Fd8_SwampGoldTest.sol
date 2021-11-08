// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title Swamp Gold Test
/// @author Jackson Green
/// @notice This contract mints Swamp Gold for NFT holders

contract SwampGoldTest is Context, Ownable, ERC20 {
    address public lootContractAddress =
        0xE5524aAD7BEf1e1bF711C55d63D9Bf9C8e2a5C2C;
    IERC721Enumerable public lootContract;

    uint256 public SwampGoldTestPerToadzTokenId = 7000 * (10**decimals());
    uint256 public SwampGoldTestPerFlyzTokenId = 7000 * (10**decimals());
    uint256 public SwampGoldTestPerTokenId = 7000 * (10**decimals());
    uint256 public tokenIdStart = 1;
    uint256 public tokenIdEnd = 8000;
    uint256 public season = 0;

    mapping(uint256 => mapping(uint256 => bool)) public seasonClaimedByTokenId;

    constructor() Ownable() ERC20("Swamp Test Token", "SGLDTOK") {
        lootContract = IERC721Enumerable(lootContractAddress);
    }

    function claimById(uint256 tokenId) external {

        require(
            _msgSender() == lootContract.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claim(tokenId, _msgSender());
    }
    
    function claimAllForOwner() external {
        uint256 tokenBalanceOwner = lootContract.balanceOf(_msgSender());

        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        for (uint256 i = 0; i < tokenBalanceOwner; i++) {
            _claim(
                lootContract.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }


    function claimRangeForOwner(uint256 ownerIndexStart, uint256 ownerIndexEnd)
        external
    {
        uint256 tokenBalanceOwner = lootContract.balanceOf(_msgSender());

        // Checks
        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        // We use < for ownerIndexEnd and tokenBalanceOwner because
        // tokenOfOwnerByIndex is 0-indexed while the token balance is 1-indexed
        require(
            ownerIndexStart >= 0 && ownerIndexEnd < tokenBalanceOwner,
            "INDEX_OUT_OF_RANGE"
        );

        // i <= ownerIndexEnd because ownerIndexEnd is 0-indexed
        for (uint256 i = ownerIndexStart; i <= ownerIndexEnd; i++) {
            // Further Checks, Effects, and Interactions are contained within
            // the _claim() function
            _claim(
                lootContract.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }

    /// @dev Internal function to mint Loot upon claiming
    function _claim(uint256 tokenId, address tokenOwner) internal {

        require(
            tokenId >= tokenIdStart && tokenId <= tokenIdEnd,
            "TOKEN_ID_OUT_OF_RANGE"
        );

        require(
            !seasonClaimedByTokenId[season][tokenId],
            "GOLD_CLAIMED_FOR_TOKEN_ID"
        );


        seasonClaimedByTokenId[season][tokenId] = true;

        _mint(tokenOwner, SwampGoldTestPerTokenId);
    }


    function daoMint(uint256 amountDisplayValue) external onlyOwner {
        _mint(owner(), amountDisplayValue * (10**decimals()));
    }

    function daoSetLootContractAddress(address lootContractAddress_)
        external
        onlyOwner
    {
        lootContractAddress = lootContractAddress_;
        lootContract = IERC721Enumerable(lootContractAddress);
    }

    function daoSetTokenIdRange(uint256 tokenIdStart_, uint256 tokenIdEnd_)
        external
        onlyOwner
    {
        tokenIdStart = tokenIdStart_;
        tokenIdEnd = tokenIdEnd_;
    }

    function daoSetSeason(uint256 season_) public onlyOwner {
        season = season_;
    }

    function daoSetSwampGoldTestPerTokenId(uint256 SwampGoldTestDisplayValue)
        public
        onlyOwner
    {
        SwampGoldTestPerTokenId = SwampGoldTestDisplayValue * (10**decimals());
    }

    function daoSetSeasonAndSwampGoldTestPerTokenID(
        uint256 season_,
        uint256 SwampGoldTestDisplayValue
    ) external onlyOwner {
        daoSetSeason(season_);
        daoSetSwampGoldTestPerTokenId(SwampGoldTestDisplayValue);
    }
}