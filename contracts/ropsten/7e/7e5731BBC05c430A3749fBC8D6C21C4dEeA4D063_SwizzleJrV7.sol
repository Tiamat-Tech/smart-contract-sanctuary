// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SwizzleJrV7 is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    uint256 public constant MAX_MINT_PER_TRANS = 10;
    uint256 public constant PRICE_PER_NFT = 0.1 ether;
    string public constant DEFAULT_FLAVOR_URI =
        "QmNRTNPf5czhKcmq9R4pjU61nT9GaiM6EG6hVjASdqN1fr";
    string public constant tokenPartUri = "/ss";
    string public constant tokenExtension = ".json";

    string public baseURI;
    bool public mintingActive = false;
    uint256 public maxNftsForSale;
    uint256 public numberOfFlavors;
    bool public lastBitEnabled;

    Counters.Counter private _coinMintCounter;

    // Mapping
    mapping(uint256 => string) private _flavorURIs;
    mapping(uint256 => uint256) private _tokenFlavors;

    constructor() ERC721("SwizzleJrV7", "TVS-SwizzleJr-Dev-V7") {
        // Implementation version: 7
        baseURI = "https://gateway.pinata.cloud/ipfs/";
        maxNftsForSale = 999;
        numberOfFlavors = 3;
        lastBitEnabled = false;

        // Init default flavor uris.
        for (uint256 i = 1; i <= numberOfFlavors; i++) {
            _flavorURIs[i * 100] = DEFAULT_FLAVOR_URI;

            if (lastBitEnabled) {
                _flavorURIs[(i * 100) + 1] = DEFAULT_FLAVOR_URI;
            }
        }
    }

    function setMintingActive(bool __mintingActive) external onlyOwner {
        mintingActive = __mintingActive;
    }

    function assignFlavor(uint256 flavorIndex, string memory flavorUri)
        external
        onlyOwner
    {
        require(
            bytes(_flavorURIs[flavorIndex]).length > 0,
            "Flavor not exists"
        );

        _flavorURIs[flavorIndex] = flavorUri;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Nonexistent token");
        string memory base = _baseURI();
        require(bytes(base).length > 0, "Base not set");

        uint256 tokenFlavor = _tokenFlavors[tokenId];

        string memory ipfsUri;
        // If there is no flavor URI, use default uri.
        if (bytes(_flavorURIs[tokenFlavor]).length == 0) {
            ipfsUri = DEFAULT_FLAVOR_URI;
        } else {
            ipfsUri = _flavorURIs[tokenFlavor];
        }

        uint256 tokenSlot = 10000 + tokenId;

        return
            string(
                abi.encodePacked(
                    base,
                    ipfsUri,
                    tokenPartUri,
                    tokenSlot.toString(),
                    tokenExtension
                )
            );
    }

    function mintSwizzles(uint256 count) external payable {
        require(mintingActive, "Not active");
        require(0 < count && count <= MAX_MINT_PER_TRANS, "Invalid count");
        require(PRICE_PER_NFT * count == msg.value, "Invalid price");

        _mintSwizzle(msg.sender, count);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _setTokenURI(uint256 tokenId, uint256 tokenFlavor)
        internal
        virtual
    {
        require(_exists(tokenId), "Token not exist");
        _tokenFlavors[tokenId] = tokenFlavor;
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (_tokenFlavors[tokenId] > 0) {
            delete _tokenFlavors[tokenId];
        }
    }

    function _getFlavorFor(uint256 idx) private view returns (uint256) {
        uint256 theFlavor;
        uint256 lastBit = 0;

        theFlavor = (idx % numberOfFlavors) + 1; // Distribute equally.

        if (lastBitEnabled) {
            lastBit = (idx % 100) > 61 ? 1 : 0; // Distribute based on golden ratio.
        }

        return (theFlavor * 100) + lastBit;
    }

    function _mintSwizzle(address minter, uint256 count) private {
        require(minter != address(0), "Invalid address");

        uint256 initialIndex = _coinMintCounter.current();

        require(initialIndex + count <= maxNftsForSale, "Limit exceeded");

        uint256 newItemId;
        uint256 oddsIdx;
        uint256 tokenFlavor;
        for (uint256 i = 0; i < count; i++) {
            _coinMintCounter.increment();
            newItemId = _coinMintCounter.current();
            _safeMint(minter, newItemId);

            // More to do here.
            oddsIdx =
                uint256(keccak256(abi.encodePacked(newItemId, block.number))) %
                maxNftsForSale;

            tokenFlavor = _getFlavorFor(oddsIdx);
            _setTokenURI(newItemId, tokenFlavor);
        }
    }
}