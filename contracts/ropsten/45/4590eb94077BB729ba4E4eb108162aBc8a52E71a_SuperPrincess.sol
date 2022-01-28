// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SuperPrincess is ERC721, AccessControl{
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    // max token
    uint256 public maxSupply = 6000;

    // base URI
    string public _URI;

    constructor(uint256 maxNum) ERC721("SuperPrincess", "SPT") {
        maxSupply = maxNum;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view override returns (string memory) {
        return _URI;
    }

    /**
     * @dev public function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     */
    function setBaseURI(string memory uri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _URI = uri;
    }

    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < maxSupply, "mint invalid: number exceeded");
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    /*
     * @dev totalSupply
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, AccessControl)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


}