// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import './ERC721B.sol';

/**
 * @title Test Pandaz contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */

contract TestPandaz is Ownable, ERC721B {
    using Strings for uint256;

    string private _tokenBaseURI;
    uint256 public MAX_RPN_SUPPLY;

    mapping (uint256 => uint256) public lastTransfer;

    constructor() ERC721B("Test Pandaz", "TPN") {
        MAX_RPN_SUPPLY = 1500;
    }

    /**
     * Check if certain token id is exists.
     */
    function exists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    function tokenURI(uint256 tokenId) external view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    }

    /**
     * Get the array of token for owner.
     */
    function tokensOfOwner(address owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 id = 0;
            for (uint256 index = 0; index < _owners.length; index++) {
                if(_owners[index] == owner)
                result[id++] = index;
            }
            return result;
        }
    }
    
    /*
    * Set base URI
    */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _tokenBaseURI = baseURI;
    }

    /**
    * Mint Red Pandaz with 1 Phat Pandaz + 1 Plant
    */
    function mint()
        external
    {
        uint256 supply = _owners.length;

        require(supply + 1 <= MAX_RPN_SUPPLY, "Exceed max supply");

        _mint( msg.sender, supply++);
    }

    function updateLastTransfer(uint256 id, uint256 time)
        external
        onlyOwner()
    {
        lastTransfer[id] = time;
    }
}