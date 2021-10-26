//SPDX-License-Identifier: MIT
//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
pragma solidity ^0.8.0;

/*
.・。.・゜✭・.・✫・゜・。..・。.・゜✭・.・✫・゜・。.✭・.・✫・゜・。..・✫・゜・。

  ___  ____  _  _  ____  ____  _____  ___  _____  _  _  ____  _  _ 
 / __)(  _ \( \/ )(  _ \(_  _)(  _  )/ __)(  _  )( \/ )( ___)( \( )
( (__  )   / \  /  )___/  )(   )(_)(( (__  )(_)(  \  /  )__)  )  ( 
 \___)(_)\_) (__) (__)   (__) (_____)\___)(_____)  \/  (____)(_)\_)

.・。.・゜✭・.・✫・゜・。..・。.・゜✭・.・✫・゜・。.✭・.・✫・゜・。..・✫・゜・。
*/

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

// allows the contract to be ownable by the core coven
import "@openzeppelin/contracts/access/Ownable.sol";

// utilities for strings, like converting a tokenId to a string
import "@openzeppelin/contracts/utils/Strings.sol";

// utilities to ensure math operations error on overflows
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// blocks against common re-entry attacks
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CryptoCoven is ERC721Enumerable, IERC2981, ReentrancyGuard, Ownable {
    using Strings for uint256;

    string private constant BASE_URI =
        "https://cloudflare-ipfs.com/ipfs/bafybeibarf4fkhkmvkwfy3gu53i67bypmffuzktnyg4uoqpesrhlnxa37a/";

    bytes32 public constant COMMUNITY_LIST_MERKLE_ROOT =
        0x8c0ea9913137f85fe3016532857533d7b3cceceacb9df3620fff84424ce903d6;

    bool public isCommunitySaleActive = false;
    bool public isPublicSaleActive = false;
    uint256 public numGiftedWitches = 0;

    address private openSeaProxyRegistryAddress;

    uint256 public constant COMMUNITY_SALE_PRICE = 0.05 ether;
    uint256 public constant PUBLIC_SALE_PRICE = 0.07 ether;

    uint256 public constant MAX_SUPPLY = 9999;
    uint256 public constant MAX_GIFTED_WITCHES = 250;
    uint256 public constant MAX_WITCHES_PER_WALLET = 3;

    // sets the name and symbol (does not need to be defined separately)
    constructor(address _openSeaProxyRegistryAddress)
        ERC721("Crypto Coven", "COVEN")
    {
        openSeaProxyRegistryAddress = _openSeaProxyRegistryAddress;
    }

    // makes us compliant with IERC165 — allows contracts to signal to other contracts what functions they expose
    // Takes an interface, and returns a bool if the contract has that interface (what does this do?)
    /*
    // Blitmaps just extends ERC721 Enumerable (and not them both) -- do we need both?
    // ERC721 needs this defined
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    */

    function numAvailableToMint(address addr) external view returns (uint256) {
        return MAX_WITCHES_PER_WALLET - balanceOf(addr);
    }

    // -------------
    // Presale logic -- we as the owner of the contract can flip this bool, and specify which addresses are in the allowlist

    function setIsCommunitySaleActive(bool _isCommunitySaleActive)
        external
        onlyOwner
    {
        isCommunitySaleActive = _isCommunitySaleActive;
    }

    function mintCommunitySale(
        uint8 numberOfTokens,
        bytes32[] calldata merkleProof
    ) external payable {
        uint256 ts = totalSupply();

        require(isCommunitySaleActive, "Community sale is not active");
        require(
            balanceOf(msg.sender) + numberOfTokens <= MAX_WITCHES_PER_WALLET,
            "Exceeded max token purchase"
        );
        require(
            ts + numberOfTokens <= MAX_SUPPLY,
            "Purchase would exceed max tokens"
        );
        require(
            COMMUNITY_SALE_PRICE * numberOfTokens <= msg.value,
            "Ether value sent is not correct"
        );
        require(
            verify(
                COMMUNITY_LIST_MERKLE_ROOT,
                keccak256(abi.encodePacked(msg.sender)),
                merkleProof
            ),
            "Address does not exist in community sale list"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i + 1);
        }
    }

    // flip a public sale lock
    function setIsPublicSaleActive(bool _isPublicSaleActive)
        external
        onlyOwner
    {
        isPublicSaleActive = _isPublicSaleActive;
    }

    // payable -- paid transaction. Comes with a body + modified in this function
    function mint(uint256 numberOfTokens) external payable {
        uint256 ts = totalSupply();
        require(isPublicSaleActive, "Public sale is not active");
        require(
            balanceOf(msg.sender) + numberOfTokens <= MAX_WITCHES_PER_WALLET,
            "Exceeded max token purchase"
        );
        require(
            ts + numberOfTokens <= MAX_SUPPLY,
            "Purchase would exceed max tokens"
        );
        require(
            PUBLIC_SALE_PRICE * numberOfTokens <= msg.value,
            "Ether value sent is not correct"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i + 1);
        }
    }

    // Reserve some witches to our wallet to gift later
    function reserveForGifting(uint256 n) external onlyOwner {
        require(
            numGiftedWitches + n <= MAX_GIFTED_WITCHES,
            "Exceeded max witches to gift"
        );
        numGiftedWitches += n;
        uint256 ts = totalSupply();
        for (uint256 i = 0; i < n; i++) {
            _safeMint(msg.sender, ts + i + 1);
        }
    }

    // Gift a witch directly to an address
    function giftWitch(address addr) external onlyOwner {
        uint256 ts = totalSupply();
        require(
            numGiftedWitches + 1 <= MAX_GIFTED_WITCHES,
            "Exceeded max witches to gift"
        );
        require(ts + 1 <= MAX_SUPPLY, "Gifting would exceed max tokens");
        numGiftedWitches += 1;

        _safeMint(addr, ts + 1);
    }

    // Gift multiple witches directly to a list of addresses
    function giftWitches(address[] calldata addresses) external onlyOwner {
        uint256 ts = totalSupply();
        uint256 numberToGift = addresses.length;
        require(
            numGiftedWitches + numberToGift <= MAX_GIFTED_WITCHES,
            "Exceeded max witches to gift"
        );
        require(
            ts + numberToGift <= MAX_SUPPLY,
            "Gifting would exceed max tokens"
        );
        numGiftedWitches += numberToGift;

        for (uint256 i = 0; i < numberToGift; i++) {
            if (balanceOf(addresses[i]) < MAX_WITCHES_PER_WALLET) {
                _safeMint(addresses[i], ts + i + 1);
            }
        }
    }

    function verify(
        bytes32 root,
        bytes32 leaf,
        bytes32[] memory proof
    ) private pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }

    /**
     * @dev Override isApprovedForAll to allowlist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        // Get a reference to OpenSea's proxy registry contract by instantiating
        // the contract using the already existing address.
        ProxyRegistry proxyRegistry = ProxyRegistry(
            openSeaProxyRegistryAddress
        );
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
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

        return string(abi.encodePacked(BASE_URI, tokenId.toString(), ".json"));
    }

    /**
     * @dev See {IERC165-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");

        return (address(this), SafeMath.div(SafeMath.mul(salePrice, 5), 100));
    }
}

// These contract definitions are used to create a reference to the OpenSea
// ProxyRegistry contract by using the registry's address (see isApprovedForAll).
contract OwnableDelegateProxy {

}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}