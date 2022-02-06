// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// @title:      Magic Moosh
// @twitter:    https://twitter.com/MagicMooshNFT
// @url:        https://www.magicmoosh.com/
// shoutout to Chiba Labs - xo @eternitybro
/**
*
█▀▄▀█ ▄▀█ █▀▀ █ █▀▀   █▀▄▀█ █▀█ █▀█ █▀ █░█
█░▀░█ █▀█ █▄█ █ █▄▄   █░▀░█ █▄█ █▄█ ▄█ █▀█
*
**/

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MagicMoosh is ERC721A, Ownable, ReentrancyGuard {
    using Address for address;

    address proxyRegistryAddress;

    uint256 public immutable COLLECTION_SIZE = 1111;

    uint256 public maxPerMint = 10;

    constructor() ERC721A("Magic Moosh", "MOOSH") {}

    // ------- Variables -------
    string private baseTokenURI;
    uint256 public nextOwnerToExplicitlySet;
    uint256 public mintPrice = 0.023 ether;

    // ------ Mint settings ------
    bool public isMintActive = false;

    // ----- Modifiers ------
    function _onlySender() private view {
        require(tx.origin == msg.sender, "You are not the sender!");
    }

    modifier onlySender() {
        _onlySender();
        _;
    }

    /**
     * MINTY MOOSH
     */
    function mint(uint256 quantity) external payable onlySender {
        require(mintPrice * quantity == msg.value, "Exact amount needed");
        require(isMintActive, "Mint is not active");
        require(quantity > 0, "Minted amount should be positive");
        require(quantity < maxPerMint, "Minted amount exceeds sale limit");
        require(totalSupply() + quantity < COLLECTION_SIZE + 1, "Out of stock");

        _safeMint(msg.sender, quantity);
    }

    function flipMintState() external onlyOwner {
        isMintActive = !isMintActive;
    }

    //  ------- Setters (owner only) -------
    function setMaxMintAmount(uint256 _newMaxMintAmount) external onlyOwner {
        maxPerMint = _newMaxMintAmount;
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function setOwnersExplicit(uint256 quantity) external onlyOwner nonReentrant {
        _setOwnersExplicit(quantity);
    }

    /**
     *  Explicitly set `owners` to eliminate loops in future calls of ownerOf().
     */
    function _setOwnersExplicit(uint256 quantity) internal {
        require(quantity != 0, "quantity must be nonzero");
        require(currentIndex != 0, "no tokens minted yet");
        uint256 _nextOwnerToExplicitlySet = nextOwnerToExplicitlySet;
        require(_nextOwnerToExplicitlySet < currentIndex, "all ownerships have been set");

        // Index underflow is impossible.
        // Counter or index overflow is incredibly unrealistic.
        unchecked {
            uint256 endIndex = _nextOwnerToExplicitlySet + quantity - 1;

            // Set the end index to be the last token index
            if (endIndex + 1 > currentIndex) {
                endIndex = currentIndex - 1;
            }

            for (uint256 i = _nextOwnerToExplicitlySet; i <= endIndex; i++) {
                if (_ownerships[i].addr == address(0)) {
                    TokenOwnership memory ownership = ownershipOf(i);
                    _ownerships[i].addr = ownership.addr;
                    _ownerships[i].startTimestamp = ownership.startTimestamp;
                }
            }

            nextOwnerToExplicitlySet = endIndex + 1;
        }
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId) external view returns (TokenOwnership memory) {
        return ownershipOf(tokenId);
    }

    //sets the opensea proxy
    function setProxyRegistry(address _newRegistry) external onlyOwner {
        proxyRegistryAddress = _newRegistry;
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
}

//opensea removal of approvals
contract OwnableDelegateProxy {

}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}