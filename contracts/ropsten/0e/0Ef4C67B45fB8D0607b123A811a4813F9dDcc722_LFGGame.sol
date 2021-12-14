// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "./LFGToken.sol";
import "./LFGStartup.sol";
import "./LFGRecommendation.sol";

// Main game contract
// - Mint a startup account
// - Recommend a startup (burning $LFG in their name)
contract LFGGame is Context, Ownable, Pausable, ReentrancyGuard {
    address public alumniGemContractAddress;
    address public lfgTokenContractAddress;
    address public lfgStartupContractAddress;
    address public lfgRecommendationContractAddress;

    // Give out 10,000 LFG to each alumni
    uint256 public tokensPerAlumni = 10000;

    // Keep track of who already claimed
    mapping(uint256 => bool) public claimedByGemId;

    mapping(address => bool) public claimedByAddress;

    constructor(
        address _alumniGemContractAddress,
        address _lfgTokenContractAddress,
        address _lfgStartupContractAddress,
        address _lfgRecommendationContractAddress
    ) {
        alumniGemContractAddress = _alumniGemContractAddress;
        lfgTokenContractAddress = _lfgTokenContractAddress;
        lfgStartupContractAddress = _lfgStartupContractAddress;
        lfgRecommendationContractAddress = _lfgRecommendationContractAddress;
    }

    function claimLFG() external whenNotPaused nonReentrant {
        // Disabled for testnet - alumni gems not widely distributed
        // IERC721Enumerable alumniGemContract = IERC721Enumerable(alumniGemContractAddress);
        // require(alumniGemContract.balanceOf(_msgSender()) > 0, "Only Gem holders can claim");

        // MUST FIRST ADD ENUMERABLE SUPPORT TO ALUMNI GEMS
        // uint256 gemId = alumniGemContract.tokenOfOwnerByIndex(_msgSender(), 0);
        // require(!claimedByGemId[gemId], "Already claimed LFG for this Gem");

        // Can remove this check when above gem check is working
        require(!claimedByAddress[_msgSender()], "Already claimed LFG for this wallet");

        // claimedByGemId[gemId] = true;
        claimedByAddress[_msgSender()] = true;
        LFGToken(lfgTokenContractAddress).mint(_msgSender(), tokensPerAlumni);
    }

    function createStartup(bytes32 _hash, bytes32 salt) external whenNotPaused nonReentrant returns (uint256) {
        // must be LFG holder?
        return LFGStartup(lfgStartupContractAddress).createStartup(_msgSender(), _hash, salt);
    }

    function revealStartup(uint256 startupId, string memory startupName) external whenNotPaused nonReentrant {
        // must be LFG holder?
        LFGStartup(lfgStartupContractAddress).revealStartup(startupId, startupName);
    }

    function createAndRevealStartup(string memory startupName) external whenNotPaused nonReentrant returns (uint256) {
        // must be LFG holder?
        bytes32 salt = pseudoRandomSalt();
        bytes32 _hash = keccak256(abi.encodePacked(startupName, salt));

        LFGStartup lfgStartup = LFGStartup(lfgStartupContractAddress);
        uint256 startupId = lfgStartup.createStartup(_msgSender(), _hash, salt);
        lfgStartup.revealStartup(startupId, startupName);

        return startupId;
    }

    function recommendStartup(uint256 startupId, uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be >0");
        LFGToken lfgToken = LFGToken(lfgTokenContractAddress);
        require(lfgToken.balanceOf(_msgSender()) >= amount, "Sender balance is less than bet amount");

        lfgToken.burn(_msgSender(), amount);
        LFGRecommendation(lfgStartupContractAddress).recommendStartup(_msgSender(), startupId, amount);
    }

    function setStartupAccepted(uint256 startupId, bool accepted) external whenNotPaused nonReentrant {
        // if owner of Startup NFT - has YC gem - company must be accepted
        // must be startup owner
        // and LFG holder

        LFGStartup(lfgStartupContractAddress).setStartupAccepted(startupId, accepted);
    }

    function getStartup(uint256 startupId) external view returns (LFGStartup.Startup memory) {
        return LFGStartup(lfgStartupContractAddress).getStartup(startupId);
    }

    function pseudoRandomSalt() private view returns (bytes32) {
        return keccak256(abi.encodePacked(block.difficulty, block.timestamp, _msgSender()));
    }
}