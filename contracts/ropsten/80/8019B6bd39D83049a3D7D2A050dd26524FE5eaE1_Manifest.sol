// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/*

..................................................
..................................................
..................................................
..................................................
..................................................
...............                    ...............
...............                    ...............
...............                    ...............
...............      MANIFEST      ...............
...............                    ...............
...............                    ...............
...............                    ...............
...................................
...................................
...................................
...................................
...................................

*/

contract Manifest is ERC721Enumerable, Ownable, ReentrancyGuard {
    uint256 public constant MAX_MANIFESTS = 1_000;

    // Public sale params
    uint256 public maxPerTransaction = 5;
    uint256 public manifestPrice = 0.12 ether;
    bool public publicSaleActive;
    uint256 private _amountPurchased;

    // Free mints for Crypto Planet holders
    //
    // Each holder of a @GotTheJoose crypto planet receives a free Manifest
    // mint as a thank you for their early support. Check out the crypto
    // planets here! https://foundation.app/@joose

    // Note: These are minted from the supply of 1,000 and are not extra
    // manifests in circulation.
    uint256 public constant MAX_CLAIMABLE = 20;
    uint256 private _amountClaimed;
    address[] private claimants;
    mapping(address => uint256) private claimantAllocations;

    // Limited edition Manifests
    //
    // We allow a further 10 Manifests to be created by the team at an
    // indeterminate date in the future. This will allow for limited edition
    // manifests to be created for promo reasons.
    uint256 public constant LIMITED_EDITION_MAX = 10;
    uint256 private _limitedEditionsMinted;

    // Provenance + Fairness
    string public provenanceHash;
    string public baseURI;
    uint256 public startingIndexBlock;
    uint256 public startingIndex;
    uint256 public revealTimestamp;
    // We lock them ahead of mint.
    bool public provenanceLocked;
    bool public baseURILocked;

    event ProvenanceSubmitted(
        string provenanceHash,
        uint256 timestamp
    );
    event BaseURISubmitted(
        string baseURI,
        uint256 timestamp
    );

    modifier whenPublicSaleActive {
        require(publicSaleActive, "Public sale not active");
        _;
    }

    modifier notLocked(bool target) {
        require(!target, "Locked");
        _;
    }

    constructor() ERC721("Manifest", "MANI") {}

    function mintManifest(uint256 purchaseAmount)
        external
        payable
        whenPublicSaleActive
        nonReentrant
    {
        require(purchasableSupply() > 0, "Sold out");

        if (purchaseAmount > purchasableSupply()) {
            purchaseAmount = purchasableSupply();
        }

        if (purchaseAmount > maxPerTransaction) {
            purchaseAmount = maxPerTransaction;
        }

        uint256 totalCost = purchaseAmount*manifestPrice;
        require(msg.value >= totalCost, "Not enough ETH sent");

        for(uint i = 0; i < purchaseAmount; i++) {
            uint256 newTokenId = _getNewTokenId();
            _amountPurchased += 1;
            _safeMint(msg.sender, newTokenId);
        }

        // Refund any extra ETH sent.
        if (msg.value > totalCost) {
            Address.sendValue(payable(msg.sender), msg.value - totalCost);
        }

        _setStartingIndexBlock();
    }

    function claimManifests() external whenPublicSaleActive nonReentrant {
        uint256 amountToClaim = amountClaimable();
        require(amountToClaim > 0, "Nothing to claim");

        claimantAllocations[msg.sender] = 0;

        for (uint i = 0; i < amountToClaim; i++) {
            uint256 newTokenId = _getNewTokenId();
            _amountClaimed += 1;
            _safeMint(msg.sender, newTokenId);
        }

        _setStartingIndexBlock();
    }

    function mintLtdEditionManifest() external onlyOwner {
        require(
            _limitedEditionsMinted < LIMITED_EDITION_MAX,
            "Maximum amount of limited editions have been minted"
        );

        uint256 newTokenId = MAX_MANIFESTS + _limitedEditionsMinted + 1;
        _limitedEditionsMinted += 1;

        _safeMint(msg.sender, newTokenId);
    }

    function addClaimant(address claimant, uint256 allocation)
        external
        onlyOwner
    {
        require(allocation > 0, "Allocation must be greater than 0");
        uint256 totalClaimable = _totalAmountClaimableExcludingClaimant(claimant);
        require(
            totalClaimable + _amountClaimed + allocation <= MAX_CLAIMABLE,
            "Maximum claimable amount exceeded"
        );

        if (claimantAllocations[claimant] == 0) {
            // If they've not been seen before, add them to the claimants array.
            claimants.push(claimant);
        }

        claimantAllocations[claimant] = allocation;
    }

    // In case we need to revoke an allocation
    function resetClaimantAllocation(address claimant) external onlyOwner {
        claimantAllocations[claimant] = 0;
    }

    function togglePublicSaleActive() external onlyOwner {
        if (revealTimestamp == 0) {
            revealTimestamp = block.timestamp + (86400 * 7);
        }

        publicSaleActive = !publicSaleActive;
    }

    function setStartingIndex() external {
        require(startingIndex == 0, "Starting index already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex = uint256(blockhash(startingIndexBlock)) % MAX_MANIFESTS;

        if ((block.number - startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number - 1)) % MAX_MANIFESTS;
        }

        if (startingIndex == 0) {
            startingIndex += 1;
        }
    }

    function setProvenance(string memory provenance)
        external
        onlyOwner
        notLocked(provenanceLocked)
    {
        provenanceHash = provenance;
        emit ProvenanceSubmitted(provenance, block.timestamp);
    }

    function setBaseURI(string memory uri)
        external
        onlyOwner
        notLocked(baseURILocked)
    {
        baseURI = uri;
        emit BaseURISubmitted(uri, block.timestamp);
    }

    function lockBaseURI() external onlyOwner { baseURILocked = true; }
    function lockProvenance() external onlyOwner { provenanceLocked = true; }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(msg.sender), balance);
    }

    function amountClaimable() public view returns (uint256) {
        return claimantAllocations[msg.sender];
    }

    function purchasableSupply() public view returns(uint256) {
        return (MAX_MANIFESTS - MAX_CLAIMABLE - _amountPurchased);
    }

    // Set the starting index block once all public supply has been minted or
    // 1 week after public sale begins.
    function _setStartingIndexBlock() internal {
        bool timeToReveal = block.timestamp > revealTimestamp;
        bool soldOut = totalSupply() - _limitedEditionsMinted == MAX_MANIFESTS;

        if (startingIndexBlock == 0 && soldOut || timeToReveal) {
            startingIndexBlock = block.number;
        }
    }

    function _totalAmountClaimableExcludingClaimant(address excludeAddress)
        internal
        view
        returns (
            uint256 totalAmountClaimable
        )
    {
        uint256 currentTotalAmountClaimable = 0;

        for (uint i = 0; i < claimants.length; i++) {
            if (claimants[i] == excludeAddress) {
                continue;
            }

            currentTotalAmountClaimable += claimantAllocations[claimants[i]];
        }

        return currentTotalAmountClaimable;
    }

    function _getNewTokenId() internal view returns (uint256 tokenId) {
        return _amountClaimed + _amountPurchased + 1;
    }

    function _baseURI() internal view override returns(string memory) {
        return baseURI;
    }
}