// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./IRoyaltyOverride.sol";
import "../specs/IEIP2981.sol";

/**
 * Simple EIP2981 reference override implementation
 */
contract EIP2981RoyaltyOverrideCloneable is IEIP2981, IEIP2981RoyaltyOverride, OwnableUpgradeable, ERC165 {
    using EnumerableSet for EnumerableSet.UintSet;

    function initialize() public initializer {
        __Ownable_init();
    }

    TokenRoyalty public defaultRoyalty;
    mapping(uint256 => TokenRoyalty) private _tokenRoyalties;
    EnumerableSet.UintSet private _tokensWithRoyalties;

    function setTokenRoyalties(TokenRoyaltyConfig[] memory royaltyConfigs) external override onlyOwner {
        for (uint i = 0; i < royaltyConfigs.length; i++) {
            TokenRoyaltyConfig memory royaltyConfig = royaltyConfigs[i];
            if (royaltyConfig.recipient == address(0)) {
                delete _tokenRoyalties[royaltyConfig.tokenId];
                _tokensWithRoyalties.remove(royaltyConfig.tokenId);
                emit TokenRoyaltyRemoved(royaltyConfig.tokenId);
            } else {
                _tokenRoyalties[royaltyConfig.tokenId] = TokenRoyalty(royaltyConfig.recipient, royaltyConfig.bps);
                _tokensWithRoyalties.add(royaltyConfig.tokenId);
                emit TokenRoyaltySet(royaltyConfig.tokenId, royaltyConfig.recipient, royaltyConfig.bps);
            }
        }
    }

    function setDefaultRoyalty(TokenRoyalty memory royalty) external override onlyOwner {
        defaultRoyalty = TokenRoyalty(royalty.recipient, royalty.bps);
        emit DefaultRoyaltySet(royalty.recipient, royalty.bps);
    }

    function getTokenRoyaltiesCount() external override view returns(uint256) {
        return _tokensWithRoyalties.length();
    }

    function getTokenRoyaltyByIndex(uint256 index) external override view returns(TokenRoyaltyConfig memory) {
        uint256 tokenId = _tokensWithRoyalties.at(index);
        TokenRoyalty memory royalty = _tokenRoyalties[tokenId];
        return TokenRoyaltyConfig(tokenId, royalty.recipient, royalty.bps);
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IEIP2981).interfaceId || interfaceId == type(IEIP2981RoyaltyOverride).interfaceId || super.supportsInterface(interfaceId);
    }

    function royaltyInfo(uint256 tokenId, uint256 value) public override view returns (address, uint256) {
        if (_tokenRoyalties[tokenId].recipient != address(0)) {
            return (_tokenRoyalties[tokenId].recipient, value*_tokenRoyalties[tokenId].bps/10000);
        }
        if (defaultRoyalty.recipient != address(0) && defaultRoyalty.bps != 0) {
            return (defaultRoyalty.recipient, value*defaultRoyalty.bps/10000);
        }
        return (address(0), 0);
    }
}