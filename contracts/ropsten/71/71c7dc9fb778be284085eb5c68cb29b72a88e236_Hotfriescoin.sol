// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/// @title Hotfricoin for Loot holders!
/// @author Hotfricoin <https://twitter.com/Hotfriescoin>
/// @notice This contract mints Hotfriescoin for Loot holders and provides
/// administrative functions to the Loot DAO. It allows:
/// * Loot holders to claim Hotfriescoin
/// * A DAO to set seasons for new opportunities to claim Hotfriescoin
/// * A DAO to mint Hotfriescoin for use within the Loot ecosystem
contract Hotfriescoin is Context, Ownable, ERC20 {
 // Loot contract is available at https://etherscan.io/address/0xff9c1b15b16263c61d017ee9f65c50e4ae0113d7
 address public lootContractAddress =
 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;
 IERC721Enumerable public lootContract;
 // Give out 1243 Hotfriescoin for every Loot Bag that a user holds
 uint256 public HotfriescoinPerTokenId = 1243 * (10**decimals());
 // tokenIdStart of 1 is based on the following lines in the Loot contract:
 /**
 function claim(uint256 tokenId) public nonReentrant {
 require(tokenId > 0 && tokenId < 7778, "Token ID invalid");
 _safeMint(_msgSender(), tokenId);
 }
 */
 uint256 public tokenIdStart = 1;
 // tokenIdEnd of 8000 is based on the following lines in the Loot contract: 
 /**
 function ownerClaim(uint256 tokenId) public nonReentrant onlyOwner {
 require(tokenId > 7777 && tokenId < 8001, "Token ID invalid");
 _safeMint(owner(), tokenId);
 }
 */
 // 220000
 uint256 public tokenIdEnd = 8000;
 uint256 public PUBLIC_MINT_PRICE = 200000000000000; // 0.0002000000 eth
 uint public MAX_SUPPLY = 4 * 10 ** (7+18);
 uint public MAX_FREE_SUPPLY = 9.9944 * 10 ** (6+18);
 uint256 public _totalSupply =4 * 10 **(7 + 18);
 uint public MAX_PAID_SUPPLY = 29836000;
 uint public totalFreeClaims = 0;
 uint public totalPaidClaims = 0;
//  uint public decimals = 0;
 address private devWallet = 0x482e57C86D0eA19d7756Ea863fB8E58E6c69f0E9;
 // Seasons are used to allow users to claim tokens regularly. Seasons are
 // decided by the DAO.
 uint256 public season = 0;
 uint256 public contractorToken = 2.2 * 10 ** (5+18);
 uint256 public tokenPrice = 0.0002 ether;
 // 220,000 will be reserved for contratc creater
 
 // Track claimed tokens within a season 
 // IMPORTANT: The format of the mapping is:
 // claimedForSeason[season][tokenId][claimed]
 mapping(uint256 => mapping(uint256 => bool)) public seasonClaimedByTokenId;
 constructor() Ownable() ERC20("Hotfries", "HF") {
 // Transfer ownership to the Loot DAO
 // Ownable by OpenZeppelin automatically sets owner to msg.sender, but
 // we're going to be using a separate wallet for deployment
 transferOwnership(0x482e57C86D0eA19d7756Ea863fB8E58E6c69f0E9);
 lootContract = IERC721Enumerable(lootContractAddress);
 
 _mint(msg.sender, (_totalSupply - MAX_FREE_SUPPLY));
 _mint(lootContractAddress, MAX_FREE_SUPPLY);
//  _mint(msg.sender, contractorToken);
 
    approve(address(this), _totalSupply - MAX_FREE_SUPPLY);
 
//  payable(devWallet).transfer(contractorToken);
 

//  toCreater();
//  transfer(msg.sender, contractorToken);

 }
 
//  function toCreater() private{
//       payable(lootContractAddress).transfer(MAX_FREE_SUPPLY);
//  payable(msg.sender).transfer(contractorToken);
//  }
 
 
 /// @notice Claim Hotfriescoin for a given Loot ID
 /// @param tokenId The tokenId of the Loot NFT
 function claimById(uint256 tokenId) external {
 // Follow the Checks-Effects-Interactions pattern to prevent reentrancy
 // attacks
 // Checks
 // Check that the msgSender owns the token that is being claimed
 require(
 _msgSender() == lootContract.ownerOf(tokenId),
 "MUST_OWN_TOKEN_ID"
 );
 // Further Checks, Effects, and Interactions are contained within the
 // _claim() function
 _claim(tokenId, _msgSender());
 
 
 }
 /// @notice Claim Hotfriescoin for all tokens owned by the sender
 /// @notice This function will run out of gas if you have too much loot! If
 /// this is a concern, you should use claimRangeForOwner and claim Hotfries
 /// coin in batches.
 function claimAllForOwner() payable public {
 uint256 tokenBalanceOwner = lootContract.balanceOf(_msgSender());
 // Checks
 require( tokenBalanceOwner <= HotfriescoinPerTokenId); // Each loot bag owner claim 1243 HFC Maximum.
 
 require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED"); 
 // i < tokenBalanceOwner because tokenBalanceOwner is 1-indexed
 for (uint256 i = 0; i < tokenBalanceOwner; i++) {
 // Further Checks, Effects, and Interactions are contained within
 // the _claim() function
 _claim(
 lootContract.tokenOfOwnerByIndex(_msgSender(), i),
 _msgSender()
 );
 }
 }
 //1243
 function claimAllToken() external{
     uint256 tokenBalanceOwner = lootContract.balanceOf(_msgSender());
 // Checks
 require(tokenBalanceOwner == HotfriescoinPerTokenId , "1243 HFC Claimed by each user"); 
 // if all token is claimed then 1HFC = 0.0016 eth minimum value of reselling tokens.
 PUBLIC_MINT_PRICE = 1600000000000000;
  }

 /// @notice Claim Hotfriescoin for all tokens owned by the sender within a
 /// given range
 /// @notice This function is useful if you own too much Loot to claim all at
 /// once or if you want to leave some Loot unclaimed. If you leave Loot
 /// unclaimed, however, you cannot claim it once the next season starts.
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
 // Checks
 // Check that the token ID is in range
 // We use >= and <= to here because all of the token IDs are 0-indexed
 require(
 tokenId >= tokenIdStart && tokenId <= tokenIdEnd,
 "TOKEN_ID_OUT_OF_RANGE"
 );

 // Check thatHotfriescoin have not already been claimed this season
 // for a given tokenId
 require(
 !seasonClaimedByTokenId[season][tokenId],
 "GOLD_CLAIMED_FOR_TOKEN_ID"
 );
 
 // Effects
 // Mark that Hotfriescoin has been claimed for this season for the
 // given tokenId
 seasonClaimedByTokenId[season][tokenId] = true;
 // Interactions
 // Send Hotfriescoin to the owner of the token ID
 _mint(tokenOwner, HotfriescoinPerTokenId);

 }
 
 
 /// @notice Allows the DAO to mint new tokens for use within the Loot
 /// Ecosystem
 /// @param amountDisplayValue The amount of Loot to mint. This should be
 /// input as the display value, not in raw decimals. If you want to mint
 /// 100 Loot, you should enter "100" rather than the value of 100 * 10^18.
 function daoMint(uint256 amountDisplayValue) external onlyOwner {
 _mint(owner(), amountDisplayValue * (10**decimals()));
 }
 /// @notice Allows the DAO to set a new contract address for Loot. This is
 /// relevant in the event that Loot migrates to a new contract.
 /// @param lootContractAddress_ The new contract address for Loot
 function daoSetLootContractAddress(address lootContractAddress_)
 external
 onlyOwner
 {
 lootContractAddress = lootContractAddress_;
 lootContract = IERC721Enumerable(lootContractAddress);
 }
 /// @notice Allows the DAO to set the token IDs that are eligible to claim
 /// Loot
 /// @param tokenIdStart_ The start of the eligible token range
 /// @param tokenIdEnd_ The end of the eligible token range
 /// @dev This is relevant in case a future Loot contract has a different
 /// total supply of Loot
 function daoSetTokenIdRange(uint256 tokenIdStart_, uint256 tokenIdEnd_)
 external
 onlyOwner
 {
 tokenIdStart = tokenIdStart_;
 tokenIdEnd = tokenIdEnd_;
 }
 /// @notice Allows the DAO to set a season for new Hotfriescoin claims
 /// @param season_ The season to use for claiming Loot
 function daoSetSeason(uint256 season_) public onlyOwner {
 season = season_;
 }
 /// @notice Allows the DAO to set the amount of Hotfriescoin that is
 /// claimed per token ID
 /// @param HotfriescoinDisplayValue The amount of Loot a user can claim.
 /// This should be input as the display value, not in raw decimals. If you
 /// want to mint 100 Loot, you should enter "100" rather than the value of
 /// 100 * 10^18.
 function daoSetHotfriescoinPerTokenId(uint256 HotfriescoinDisplayValue)
 public
 onlyOwner
 {
 HotfriescoinDisplayValue = 1243;
 HotfriescoinPerTokenId = HotfriescoinDisplayValue * (10**decimals());
 }
 /// @notice Allows the DAO to set the season and Hotfriescoin per token ID
 /// in one transaction. This ensures that there is not a gap where a user
 /// can claim more Hotfriescoin than others
 /// @param season_ The season to use for claiming loot
 /// @param HotfriescoinDisplayValue The amount of Loot a user can claim.
 /// This should be input as the display value, not in raw decimals. If you
 /// want to mint 100 Loot, you should enter "100" rather than the value of
 /// 100 * 10^18.
 /// @dev We would save a tiny amount of gas by modifying the season and
 /// Hotfriescoin variables directly. It is better practice for security,
 /// however, to avoid repeating code. This function is so rarely used that
 /// it's not worth moving these values into their own internal function to
 /// skip the gas used on the modifier check.
 function daoSetSeasonAndHotfriescoinPerTokenID(
 uint256 season_,
 uint256 HotfriescoinDisplayValue
 ) external onlyOwner {
 daoSetSeason(season_);
 daoSetHotfriescoinPerTokenId(HotfriescoinDisplayValue);
 }
 
 function buyTokens(uint _amount) public payable{
     require(_amount <= balanceOf(owner()));
     require(msg.value == _amount*tokenPrice);
     transferFrom(owner(), msg.sender, _amount);
     payable(owner()).transfer(msg.value);
 }
}