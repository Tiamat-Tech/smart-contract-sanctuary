// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LFW721 is
    Initializable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable
{
    // reserve token_id for vault marketplace
    uint64 public constant MAX_FIRST_OFFERING_SUPPLY = 14800;

    // a token_id[address] whitelist mapping, only allow address can mint a specific token_id
    mapping(uint256 => address) public whitelisted;

    string public baseUri;

    // events list
    event WhitelistMinter(address minter, uint256 token_id);

    function initialize() public initializer {
        __Ownable_init();
        __ERC721_init("LegendWarFantasay", "LFWN");
    }

    function mintFirstOffering(uint256 tokenId) public {
        require(tokenId <= MAX_FIRST_OFFERING_SUPPLY);
        require(whitelisted[tokenId] == address(0));
        // TODO: add fee

        _safeMint(_msgSender(), tokenId);
    }

    function mintWhitelist(uint256 tokenId) public {
        require(whitelisted[tokenId] == _msgSender());

        // TODO: add fee

        _safeMint(_msgSender(), tokenId);
        delete (whitelisted[tokenId]);
    }

    /**
     * @dev set base uri that is used to return nft uri.
     * Can only be called by the current owner. No validation is done
     * for the input.
     * @param uri new base uri
     */
    function setBaseURI(string calldata uri) public onlyOwner {
        baseUri = uri;
    }

    /**
     * @dev set minter whitelist for specific token_id
     * Can only be called by the current owner.
     * @param _minter minter wallet address
     * @param tokenId nft token id
     */
    function whitelist(address _minter, uint256 tokenId) public onlyOwner {
        require(whitelisted[tokenId] == address(0), "tokenId already whitelisted");

        whitelisted[tokenId] = _minter;
        emit WhitelistMinter(_minter, tokenId);
    }
}