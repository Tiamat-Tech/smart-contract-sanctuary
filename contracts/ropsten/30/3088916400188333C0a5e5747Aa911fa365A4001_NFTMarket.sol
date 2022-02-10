// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "./wallet/NFTWallet.sol";
import "./wallet/FeeWallet.sol";

contract NFTMarket is NFTWallet, FeeWallet {
    using ERC165Checker for address;

    event Sold(
        address indexed tokenContract,
        uint256 indexed tokenId,
        address indexed to
    );

    event Listed(
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 price,
        uint256 royalty
    );
    event Unlisted(address indexed tokenContract, uint256 indexed tokenId);

    struct Token {
        address tokenContract;
        uint256 tokenId;
        uint256 price;
        bool listedForSale;
    }

    mapping(bytes32 => Token) public tokenList;

    function getToken(address tokenContract, uint256 tokenId)
        public
        view
        returns (Token memory token)
    {
        return tokenList[keccak256(abi.encodePacked(tokenContract, tokenId))];
    }

    function royaltyOf(
        address tokenContract,
        uint256 tokenId,
        uint256 salePrice
    ) public view returns (address receiver, uint256 royalty) {
        require(tokenContract != address(0), "Invalid token contract address");
        bool supportsRoyalty = tokenContract.supportsInterface(
            type(IERC2981).interfaceId
        );
        return
            supportsRoyalty
                ? IERC2981(tokenContract).royaltyInfo(tokenId, salePrice)
                : (address(0), 0);
    }

    function buy(address tokenContract, uint256 tokenId) public payable {
        Token storage token = tokenList[
            keccak256(abi.encodePacked(tokenContract, tokenId))
        ];
        require(token.tokenContract != address(0), "Invalid token");
        require(
            token.listedForSale && token.price > 0,
            "Token is not for sale"
        );
        require(msg.value >= token.price, "Not enough ETH");

        // Transfer royalty
        (address receiver, uint256 royaltyAmount) = royaltyOf(
            tokenContract,
            tokenId,
            msg.value
        );
        if (receiver != address(0) && royaltyAmount > 0) {
            _deposit(receiver, royaltyAmount);
        }

        // Transfer money to the seller
        uint256 fee = token.price / 10;
        _deposit(owner(), fee);
        require(msg.value >= fee + royaltyAmount, "Not enough ETH");
        _deposit(
            ownerOf(tokenContract, tokenId),
            msg.value - fee - royaltyAmount
        );

        _transferTokenOwnership(tokenContract, tokenId, msg.sender);
        token.listedForSale = false;

        emit Sold(tokenContract, tokenId, msg.sender);
    }

    function list(
        address tokenContract,
        uint256 tokenId,
        uint256 price
    ) public {
        require(price > 0, "Invalid price");
        (, uint256 royalty) = royaltyOf(tokenContract, tokenId, price);
        require(royalty < price, "Invalid royalty amount");

        Token storage token = tokenList[
            keccak256(abi.encodePacked(tokenContract, tokenId))
        ];
        token.tokenContract = tokenContract;
        token.tokenId = tokenId;
        require(
            ownerOf(tokenContract, tokenId) == msg.sender,
            "Only owner can list token"
        );
        token.listedForSale = true;
        token.price = price;
        emit Listed(tokenContract, tokenId, price, royalty);
    }

    function unlist(address tokenContract, uint256 tokenId) public {
        Token storage token = tokenList[
            keccak256(abi.encodePacked(tokenContract, tokenId))
        ];
        require(token.tokenContract != address(0), "Invalid token");
        require(
            ownerOf(tokenContract, tokenId) == msg.sender,
            "Only owner can list token"
        );
        token.listedForSale = false;
        emit Unlisted(tokenContract, tokenId);
    }
}