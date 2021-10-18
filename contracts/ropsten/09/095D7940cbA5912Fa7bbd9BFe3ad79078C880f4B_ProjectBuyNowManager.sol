// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "../../access/SignerRoleUpgradeable.sol";
import "../../ERC721ProjectUpgradeable.sol";
import "../helper/WithTreasuryUpgradeable.sol";

/// @title Interface for NFT buy-now in a fixed price.
/// @notice This is the interface for fixed price NFT buy-now.
contract ProjectBuyNowManager is
    Initializable,
    OwnableUpgradeable,
    WithTreasuryUpgradeable,
    SignerRoleUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;

    /* ========== STRUCTS ========== */
    struct BuyNowInfo {
        uint64 startTime;
        uint64 endTime;
        uint64 edition;
        uint64 purchaseLimit;
        uint256 price;
        ERC721ProjectUpgradeable project;
        string baseURI;
    }

    /* ========== STATE VARIABLES ========== */

    uint256 public nextId;
    /// @dev buyNowId => BuyNowInfo
    mapping(uint256 => BuyNowInfo) public buyNowInfos;
    /// @dev buyer => (buyNowId => purchaseCount)
    mapping(address => mapping(uint256 => uint256)) public buyerRecords;
    /// @dev buyNowId => purchaseCount
    mapping(uint256 => uint64) public saleCounts;

    /* ========== EVENTs ========== */

    event BuyNowCreated(uint256 indexed buyNowId, BuyNowInfo info);
    event BuyNowUpdated(uint256 indexed buyNowId, BuyNowInfo info);
    event AdminCancelBuyNow(uint256 indexed buyNowId, string reason);
    event Bought(
        uint256 indexed buyNowId,
        address indexed buyer,
        address project,
        uint256 tokenId,
        uint64 printEdition
    );

    /* ========== MODIFIERS ========== */

    /// @dev Require that the caller must be an EOA account if not whitelisted.
    modifier onlyEOA() {
        require(msg.sender == tx.origin, "not eoa");
        _;
    }

    modifier onlyValidConfig(BuyNowInfo calldata buyNowInfo) {
        require(
            buyNowInfo.endTime == 0 || buyNowInfo.endTime > buyNowInfo.startTime,
            "endTime should > startTime or = 0"
        );
        require(buyNowInfo.edition > 0, "bad edition");
        require(address(buyNowInfo.project).isContract(), "bad project address");
        require(bytes(buyNowInfo.baseURI).length > 0, "bad baseURI");
        _;
    }

    /* ========== INITIALIZER ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address treasuryAddress) public initializer {
        __Ownable_init();
        __WithTreasury_init();
        __SignerRole_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        setTreasury(payable(treasuryAddress));
        nextId = 1;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice buy one NFT token of specific artwork. Needs a proper signature of allowed signer to verify purchase.
    /// @param  _buyNowId uint256 the id of the buyNow artwork
    /// @param  v uint8 v of the signature
    /// @param  r bytes32 r of the signature
    /// @param  s bytes32 s of the signature
    function buyNow(
        uint256 _buyNowId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable onlyEOA nonReentrant whenNotPaused {
        // check status first, saving gas if is sold out or over
        BuyNowInfo storage buyNowInfo = buyNowInfos[_buyNowId];
        require(buyNowInfo.edition > 0, "ProjectBuyNowManager: not on sale");
        require(buyNowInfo.edition > saleCounts[_buyNowId], "ProjectBuyNowManager: sold out");
        require(buyNowInfo.startTime <= block.timestamp, "ProjectBuyNowManager: not started yet");
        require(
            buyNowInfo.endTime == 0 || buyNowInfo.endTime >= block.timestamp,
            "ProjectBuyNowManager: already ended"
        );
        require(buyNowInfo.price == msg.value, "ProjectBuyNowManager: ETH amount should match price");

        // check purchase limit, and increase buyer record
        uint256 alreadyBought = buyerRecords[_msgSender()][_buyNowId]++;
        require(
            buyNowInfo.purchaseLimit == 0 || alreadyBought < buyNowInfo.purchaseLimit,
            "ProjectBuyNowManager: you have reached purchase limit"
        );

        // check signature
        bytes32 messageHash = keccak256(abi.encode(block.chainid, address(this), _msgSender(), _buyNowId));
        require(_verifySignedMessage(messageHash, v, r, s), "ProjectBuyNowManager: proper signature is required");

        // print edition, for every buyNow artwork, it starts from 1, so ++ first, maximum is buyNowInfo.edition;
        uint64 printEdition = ++saleCounts[_buyNowId];

        _sendETHToTreasury(buyNowInfo.price);

        // mint token to the buyer, uri is base + printEdition
        uint256 tokenId = buyNowInfo.project.managerMint(
            _msgSender(),
            string(abi.encode(buyNowInfo.baseURI, uint256(printEdition).toString()))
        );

        emit Bought(_buyNowId, _msgSender(), address(buyNowInfo.project), tokenId, printEdition);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice admin setup a buy-now artwork
    function createBuyNow(BuyNowInfo calldata info) public onlyValidConfig(info) onlyOwner {
        uint256 buyNowId = _getNextAndIncrementId();
        buyNowInfos[buyNowId] = info;
        emit BuyNowCreated(buyNowId, info);
    }

    /// @notice admin can update buy now info if not started already
    function updateBuyNow(uint256 _buyNowId, BuyNowInfo calldata newInfo) public onlyValidConfig(newInfo) onlyOwner {
        BuyNowInfo storage info = buyNowInfos[_buyNowId];
        require(info.edition > 0, "no buyNow info");
        require(info.startTime < block.timestamp, "already started");
        buyNowInfos[_buyNowId] = newInfo;
        emit BuyNowUpdated(_buyNowId, newInfo);
    }

    /**
     * @notice Allows TR Lab to cancel a buyNow. If it's not started yet, it can be canceled directly.
     * If it's already started, the reason must be provided.
     * This should only be used for extreme cases such as DMCA takedown requests.
     */
    function adminCancelBuyNow(uint256 _buyNowId, string memory reason) public onlyOwner {
        BuyNowInfo storage info = buyNowInfos[_buyNowId];
        require(info.edition > 0, "no buyNow info");
        require(info.startTime < block.timestamp || bytes(reason).length > 0, "Include a reason for this cancellation");
        delete buyNowInfos[_buyNowId];
        emit AdminCancelBuyNow(_buyNowId, reason);
    }

    /// @dev pause the contract
    function pause() public onlyOwner {
        _pause();
    }

    /// @dev unpause the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    function _getNextAndIncrementId() internal returns (uint256) {
        return nextId++;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}