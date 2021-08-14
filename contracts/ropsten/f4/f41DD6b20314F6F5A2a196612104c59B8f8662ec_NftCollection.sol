// SPDX-License-Identifier: MIT

/// @title NftCollection

pragma solidity ^0.8.6;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IProxyRegistry} from "./IProxyRegistry.sol";

contract NftCollection is IERC721, Ownable, ERC721Enumerable {

    uint256 public constant PRICE = 0.05 ether;
    uint256 public constant MAX_SUPPLY = 1_000;
    uint256 public constant MAX_MINT_AMOUNT = 3;
    bool public isSaleActive = false;
    string private _contractURI =
        "ipfs://bafybeihlyjpvj3gwotikoihjmb2lma2e3jxdokwa3eofnd62tm5eowkauq";
    string public baseURI = "https://storageapi.fleek.co/jorgeacortes-team-bucket/nft-test/traits/";

    // OpenSea's Proxy Registry
    IProxyRegistry public immutable proxyRegistry;

    constructor(IProxyRegistry _proxyRegistry)
        ERC721("NftCollection", "COLLECTION")
    {
        proxyRegistry = _proxyRegistry;
    }

    /// @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
    function isApprovedForAll(address owner, address operator)
        public
        view
        override(IERC721, ERC721)
        returns (bool)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /// @notice Public mints
    function mint(uint256 amount) public payable {
        uint256 currentTotalSupply = totalSupply();

        /// @notice Cannot exceed maximum supply
        require(
            currentTotalSupply + amount <= MAX_SUPPLY,
            "All tokens have been already minted"
        );

        /// @notice public can mint mint a maximum quantity at a time.
        require(
            amount <= MAX_MINT_AMOUNT,
            "Mint amount exceeds maximum allowed"
        );

        /// @notice public can mint only when the sale is open to the public
        require(isSaleActive, "Sale not yet open to the public");

        /// @notice public must send correct funds
        require(
            msg.value > 0 && msg.value == amount * PRICE,
            "Wrong funds send for paying the mint"
        );

        _mintAmountTo(msg.sender, amount, currentTotalSupply);
    }

    /// @notice Mint starts from 1 instead of 0.
    function _mintAmountTo(
        address to,
        uint256 amount,
        uint256 startId
    ) internal {
        for (uint256 i = 1; i <= amount; i++) {
            _mint(to, startId + i);
        }
    }

    function startSale() external onlyOwner {
        isSaleActive = true;
    }

    function stopSale() external onlyOwner {
        isSaleActive = false;
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setContractURI(string memory newContractURI) external onlyOwner {
        _contractURI = newContractURI;
    }

    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    function withdrawEarnings() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

}