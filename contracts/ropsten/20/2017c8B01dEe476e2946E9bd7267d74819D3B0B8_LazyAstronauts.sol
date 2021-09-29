// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./AffiliateFactory.sol";
import "./OptimizedOwnable.sol";
import "./EquitySplitter.sol";

contract LazyAstronauts is
    OptimizedOwnable,
    Pausable,
    ERC721,
    AffiliateFactory,
    ReentrancyGuard,
    EquitySplitter
{
    using Strings for uint256;

    /// @dev Emitted when {setTokenURI} is executed.
    event TokenURISet(string indexed tokenUri);
    /// @dev Emitted when {lockTokenURI} is executed (once-only).
    event TokenURILocked(string indexed tokenUri);
    /// @dev Emitted when a whitelisted account claims NFTs
    event Claimed(address indexed account, uint256 indexed amount);

    uint256 public totalSupply;

    string public constant PROVENANCE =
        "9e33c54af18de47d56984f4eda22066fab48b9dc2b1ead461022210413f76467";
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant RESERVED_COMMUNITY = 30;
    uint256 public constant RESERVED_WHITELIST = 20;
    uint256 public constant FREE_MINT_SUPPLY =
        MAX_SUPPLY - RESERVED_COMMUNITY - RESERVED_WHITELIST;
    uint256 public constant PACK_LIMIT = 20;
    // Fri Oct 15 2021 04:00:00 GMT+0000
    uint256 public constant SALE_START = 1634270400;
    uint256 public constant PRICE = 1 ether / 20;

    string private constant METADATA_INFIX = "/metadata/";

    uint256 public communityMints;
    uint256 public whitelistMints;
    bool public tokenURILocked;
    string private _baseTokenUri;

    bytes32 public merkleRoot;
    uint256 private claimedBitMap;

    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }

    constructor(bytes32 merkleRoot_, address stakeholder_)
        ERC721("Lazy Astronauts", "LA")
        AffiliateFactory()
        EquitySplitter(stakeholder_)
    {
        merkleRoot = merkleRoot_;
    }

    function pause() external {
        _enforceOnlyOwner();
        _pause();
    }

    function resume() external {
        _enforceOnlyOwner();
        _unpause();
    }

    function deployAffiliate(
        address affiliateAddress,
        uint256 mintingPriceWei,
        uint256 affiliateFeeWei
    ) external returns (address) {
        _enforceOnlyOwner();
        _enforceAffiliatePolicies(
            affiliateAddress,
            mintingPriceWei,
            affiliateFeeWei
        );

        return
            AffiliateFactory._createAffiliate(
                address(this),
                affiliateAddress,
                mintingPriceWei,
                affiliateFeeWei
            );
    }

    function suspendAffiliateGateway(address gateway) external {
        _enforceOnlyOwner();
        AffiliateFactory._suspend(gateway);
    }

    function resumeAffiliateGateway(address gateway) external {
        _enforceOnlyOwner();
        AffiliateFactory._resume(gateway);
    }

    function executeAffiliateMint(address buyer, uint256 tokens)
        external
        payable
        override
        whenNotPaused
    {
        _enforceOnlyAffiliateGateways();
        require(block.timestamp > SALE_START, "WaitForSaleToStart");

        _enforceMintingPolicy(tokens);
        _executeMint(buyer, tokens);
    }

    function mint(uint256 astros) external payable whenNotPaused {
        require(block.timestamp > SALE_START, "WaitForSaleToStart");
        _enforcePricePolicy(astros);
        _enforceMintingPolicy(astros);
        _executeMint(msg.sender, astros);
    }

    function communityMint(uint256 astros, address to) external {
        _enforceOnlyOwner();
        require(
            communityMints + astros <= RESERVED_COMMUNITY,
            "MintingExceedsReserve"
        );
        require(astros > 0, "ZeroNFTsRequested");
        communityMints += astros;

        _executeMint(to, astros);
    }

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        require(!_isClaimed(index), "AlreadyClaimed");

        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "InvalidMerkleProof"
        );

        _setClaimed(index);

        whitelistMints += amount;

        emit Claimed(account, amount);

        _executeMint(account, amount);
    }

    function setTokenURI(string memory newUri) external whenUriNotLocked {
        _enforceOnlyOwner();
        _baseTokenUri = newUri;
        emit TokenURISet(_baseTokenUri);
    }

    function lockTokenURI() external {
        _enforceOnlyOwner();
        if (!tokenURILocked) {
            tokenURILocked = true;
            emit TokenURILocked(_baseTokenUri);
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "UnknownTokenId");

        return
            string(
                abi.encodePacked(
                    _baseTokenUri,
                    METADATA_INFIX,
                    tokenId.toString(),
                    ".json"
                )
            );
    }

    function isClaimed(uint256 index) external view returns (bool) {
        require(index < 6, "InvalidClaimIndex");
        return _isClaimed(index);
    }

    // ---- INTERNAL ----
    // ------------------
    function _enforcePricePolicy(uint256 tokens) internal view override {
        if (tokens * PRICE != msg.value) revert("InvalidETHAmount");
    }

    function _enforceMintingPolicy(uint256 astros) internal view override {
        uint256 freeMints = totalSupply - communityMints - whitelistMints;

        require(freeMints < FREE_MINT_SUPPLY, "SoldOut");
        require(astros > 0, "ZeroNFTsRequested");
        require(astros <= PACK_LIMIT, "BuyLimitExceeded");
        require(
            freeMints + astros <= FREE_MINT_SUPPLY,
            "MintingExceedsMaxSupply"
        );
    }

    function _enforceAffiliatePolicies(
        address aff,
        uint256 price,
        uint256 fee
    ) internal pure {
        aff; // don't need to check this, init does
        require(price > 0, "ZeroAffiliatePrice");
        require(price > fee, "FeeExceedsPrice");
    }

    function _executeMint(address to, uint256 tokens)
        internal
        override
        nonReentrant
    {
        for (uint256 t = 0; t < tokens; t++) {
            _safeMint(to, totalSupply + t);
        }
        totalSupply += tokens;
    }

    function _owner() internal view override(EquitySplitter) returns (address) {
        return owner();
    }

    function _enforceOnlyOwner() internal view override {
        require(msg.sender == owner(), "UnauthorizedAccess");
    }

    function _isClaimed(uint256 index) internal view returns (bool) {
        uint256 mask = (1 << index);
        return claimedBitMap & mask == mask;
    }

    modifier whenUriNotLocked() {
        require(!tokenURILocked, "TokenURILockedErr");
        _;
    }

    function _setClaimed(uint256 index) private {
        claimedBitMap = claimedBitMap | (1 << index);
    }
}