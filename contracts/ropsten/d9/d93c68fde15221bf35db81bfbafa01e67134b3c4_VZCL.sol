// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract VZCL is ERC721A, Ownable, ReentrancyGuard {
    using Address for address;

    // ===== Variables =====
    string public baseTokenURI;
    uint256 public collectionSize = 20;

    // ===== Constructor =====
    constructor() ERC721A("Verizon x Chibi Labs: Token of Love", "VZCL") {}

    // ===== Modifier =====
    function _onlySender() private view {
        require(msg.sender == tx.origin);
    }

    modifier onlySender {
        _onlySender();
        _;
    }

    // ===== Reserve mint =====
    function reserveMint(address to, uint256 amount) external onlySender onlyOwner nonReentrant {
        require((totalSupply() + amount) <= collectionSize, "Over collection limit");
        _safeMint(to, amount);
    }

    function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    // ===== View =====
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }
}