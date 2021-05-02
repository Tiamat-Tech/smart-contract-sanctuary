// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

// TODO: set actual start timestamp (SALE_START_TIMESTAMP)
// TODO: customize contract name, ERC721 description and symbol
contract XCrypto is
    Initializable,
    OwnableUpgradeable,
    ERC721EnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using StringsUpgradeable for uint256;

    event Reveal(string indexed provenance);

    // prepublished hash of the artwork
    string public provenance;

    // opens on ...
    uint256 public constant SALE_START_TIMESTAMP = 1619875071;

    // 21 days to reveal
    uint256 public constant REVEAL_TIMESTAMP = SALE_START_TIMESTAMP + 3 weeks;

    uint256 public constant MAX_NFT_SUPPLY = 5000;
    uint256 private constant PACK_LIMIT = 20;
    string private constant PLACEHOLDER_SUFFIX = "placeholder.json";
    string private constant METADATA_INFIX = "/metadata/";

    // bonding curve price tiers
    uint256 private constant TIER_1_PRICE = 3 ether / 2; // 1.5 ETH
    uint256 private constant TIER_2_SUPPLY_THRESHOLD = 3000;
    uint256 private constant TIER_2_PRICE = 3 ether;
    uint256 private constant TIER_3_SUPPLY_THRESHOLD = 4500;
    uint256 private constant TIER_3_PRICE = 5 ether;

    // For DAO's purposes, since "voting" power is expressed
    // in funds contributed, and the potential redeeming of
    // tokens for ETH is based on the same, we need to account
    // for price slippage that happens between tiers.

    // These two members track the actual price thresholds.
    uint256 private actualTier2SupplyByPrice;
    uint256 private actualTier3SupplyByPrice;

    // the 3 tiers have separate starting indexes
    uint256[3] public startingIndexBlocks;
    uint256[3] public startingIndexes;

    // current metadata base prefix
    string private _baseTokenUri;

    // Mapping from token ID to whether the token was minted before reveal
    mapping(uint256 => bool) private _mintedBeforeReveal;

    uint256 daoLockedFunds;
    address daoToken;

    function initialize() public initializer {
        __ERC721_init("XCrypto", "XCR");
        __ReentrancyGuard_init_unchained();
        __Ownable_init_unchained();
    }

    /// @dev Return `true` if provenance hash is set
    function artRevealed() private view returns (bool) {
        return bytes(provenance).length > 0;
    }

    /// @dev Return `true` if the NFT was minted before reveal phase.
    /// @param tokenId Id of a token (NB: non-remapped)
    function isMintedBeforeReveal(uint256 tokenId) public view returns (bool) {
        return _mintedBeforeReveal[tokenId];
    }

    /// @dev Set the address of the DAO token. Once-only.
/*     function setDAOToken(address token) public onlyOwner {
        require(token != address(0), "Zero DAO Token Address");
        require(daoToken == address(0), "DAO Token Already Set");

        daoToken = token;
    } */

    /// @dev Get current price tier.
    function getNFTPrice() public view returns (uint256 price) {
        require(
            block.timestamp >= SALE_START_TIMESTAMP,
            "Sale has not started"
        );
        require(totalSupply() < MAX_NFT_SUPPLY, "Max Supply Reached");

        uint256 currentSupply = totalSupply();

        if (currentSupply >= TIER_3_SUPPLY_THRESHOLD) {
            price = TIER_3_PRICE;
        } else if (currentSupply >= TIER_2_SUPPLY_THRESHOLD) {
            price = TIER_2_PRICE;
        } else {
            price = TIER_1_PRICE;
        }
    }

    /// @dev Mint `numberOfNfts` XCrypto tokens. Price slippage is okay between
    ///  tiers. It's a feature.
    /// @param numberOfNfts The number of tokens to mint.
    function mintNFT(uint256 numberOfNfts) public payable nonReentrant {
        //console.log("Will Mint %s NFTs", numberOfNfts);

        require(totalSupply() < MAX_NFT_SUPPLY, "Max Supply Reached");
        require(numberOfNfts > 0, "0 NFTs Requested");
        require(numberOfNfts <= PACK_LIMIT, "Buy Limit Exceeded");
        require(
            (totalSupply() + numberOfNfts) <= MAX_NFT_SUPPLY,
            "Minting Exceeds Max Supply"
        );
        require(
            (getNFTPrice() * numberOfNfts) == msg.value,
            "Invalid ETH Amount"
        );

        // lock half of the sent value in the DAO fund
        daoLockedFunds += msg.value / 2;

        for (uint256 i = 0; i < numberOfNfts; i++) {
            uint256 mintIndex = totalSupply();
            if (block.timestamp < REVEAL_TIMESTAMP) {
                _mintedBeforeReveal[mintIndex] = true;
            }
            _safeMint(msg.sender, mintIndex);
        }

        if (
            (totalSupply() >= TIER_3_SUPPLY_THRESHOLD) &&
            (actualTier3SupplyByPrice == 0)
        ) {
            console.log("Actual Tier 3 Supply By Price = %s", totalSupply());
            console.log("Starting Block for Tier 2 = %s", block.number);
            // if we have blown past tier 2
            actualTier3SupplyByPrice = totalSupply();
            startingIndexBlocks[1] = block.number;
        } else if (
            (totalSupply() >= TIER_2_SUPPLY_THRESHOLD) &&
            (actualTier2SupplyByPrice == 0)
        ) {
            console.log("Actual Tier 2 Supply By Price = %s", totalSupply());
            console.log("Starting Block for Tier 1 = %s", block.number);
            // if we have blown past tier 1
            actualTier2SupplyByPrice = totalSupply();
            startingIndexBlocks[0] = block.number;
        }

        // Note the usual [Stuck] situation where if not all tier tokens
        // have been minted, block.timestamp > REVEAL_TIMESTAMP, and no one
        // is calling {mintNFT} past that point, the code setting startingIndexBlocks
        // might not get executed. We resolve that in reveal/setStartingIndexForTier.

        // are we in the last tier?
        if (
            startingIndexBlocks[2] == 0 &&
            (totalSupply() == MAX_NFT_SUPPLY ||
                block.timestamp >= REVEAL_TIMESTAMP)
        ) {
            console.log("Starting Block for Tier 3 = %s", block.number);
            startingIndexBlocks[2] = block.number;
        }
    }

    function setStartingIndexForTier(uint256 tier) private {
        uint256 tierSupply;
        if (tier == 0) {
            tierSupply = TIER_2_SUPPLY_THRESHOLD;
        } else if (tier == 1) {
            tierSupply = TIER_3_SUPPLY_THRESHOLD - TIER_2_SUPPLY_THRESHOLD;
        } else tierSupply = MAX_NFT_SUPPLY - TIER_3_SUPPLY_THRESHOLD;

        console.log("setStartingIndex [%s, %s]", tier, tierSupply);

        // account for the [Stuck] scenario, see {mintNFT}
        if (startingIndexBlocks[tier] == 0) {
            console.log("Was Stuck");
            startingIndexBlocks[tier] = block.number;
        }

        uint256 _start =
            uint256(blockhash(startingIndexBlocks[tier])) % tierSupply;

        if (
            (_start > block.number)
                ? ((_start - block.number) > 255)
                : ((block.number - _start) > 255)
        ) {
            _start = uint256(blockhash(block.number - 1)) % tierSupply;
        }

        if (_start == 0) {
            _start = _start + 1;
        }

        startingIndexes[tier] = _start;
    }

    /// @dev This sets `startingIndexes` for tiers/tokens.
    ///  NB! -- Do call with the correct hash, since {reveal} is a once-only function.
    function reveal(string calldata phash) public onlyOwner {
        require(bytes(phash).length == 64, "Invalid Provenance Hash");
        require(startingIndexes[0] == 0, "Starting Index Already Set");
        require(
            block.timestamp >= REVEAL_TIMESTAMP ||
                totalSupply() == MAX_NFT_SUPPLY,
            "Before reveal OR full drop"
        );

        setStartingIndexForTier(0);
        setStartingIndexForTier(1);
        setStartingIndexForTier(2);

        provenance = phash;

        emit Reveal(provenance);
    }

    /// @dev Withdraw owner's ETH from this contract. This is only
    ///  callable after {reveal} has been executed.
    /// @param amount ETH amount to withdraw.
    function withdraw(uint256 amount) public onlyOwner nonReentrant {
        require(artRevealed(), "Art not yet revealed");
        require(amount > 0, "Can't withdraw 0 wei");
        require(
            amount <= (address(this).balance - daoLockedFunds),
            "Amount too high"
        );

        (bool sent, ) = payable(msg.sender).call{value: amount}("");

        require(sent, "ETH Transfer Failed");
    }

    /// @dev Return _baseTokenUri instead of the default impl's "".
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenUri;
    }

    /// @dev Set a new base URI to use in tokenURI.
    /// @param newUri Must NOT include the trailing slash.
    function setTokenURI(string calldata newUri) public onlyOwner {
        _baseTokenUri = newUri;
    }

    /// @dev Generate the placeholder URI.
    function placeholderURI() internal view returns (string memory) {
        return
            string(
                abi.encodePacked(_baseURI(), METADATA_INFIX, PLACEHOLDER_SUFFIX)
            );
    }

    /// @dev Generate a token URI.
    /// @param rTokenId A token id remapped based on `startingIndex`
    function indexedTokenURI(uint256 tier, uint256 rTokenId)
        internal
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    METADATA_INFIX,
                    (tier + 1).toString(),
                    "/",
                    rTokenId.toString(),
                    ".json"
                )
            );
    }

    /// @dev Generate a token URI. Before `startingIndex` is set
    ///  through {reveal}, returns the placeholder URI.
    /// @param tokenId A token id. (Always non-remapped.)
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory result)
    {
        require(_exists(tokenId), "Unknown tokenId");

        if (artRevealed()) {
            (uint256 tier, uint256 tierStartingIndex, uint256 tierSupply) =
                tierStartingIndexAndSupply(tokenId);

            result = indexedTokenURI(
                tier,
                (tokenId + tierStartingIndex) % tierSupply
            );
        } else {
            result = placeholderURI();
        }
    }

    /// @dev Given a tokenId, return the tier, the startingIndex, and the tier supply.
    function tierStartingIndexAndSupply(uint256 tokenId)
        private
        view
        returns (
            uint256 tier,
            uint256 index,
            uint256 supply
        )
    {
        if (tokenId < TIER_2_SUPPLY_THRESHOLD) {
            (tier, index, supply) = (
                uint256(0),
                startingIndexes[0],
                TIER_2_SUPPLY_THRESHOLD
            );
        } else if (tokenId < TIER_3_SUPPLY_THRESHOLD) {
            (tier, index, supply) = (
                1,
                startingIndexes[1],
                TIER_3_SUPPLY_THRESHOLD - TIER_2_SUPPLY_THRESHOLD
            );
        } else {
            (tier, index, supply) = (
                2,
                startingIndexes[2],
                MAX_NFT_SUPPLY - TIER_3_SUPPLY_THRESHOLD
            );
        }
    }
}