// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VZCL is ERC721, Ownable {
    using Address for address;

    // ===== Variables =====
    string public baseTokenURI;
    uint256 public collectionSize = 20;
    uint256 private currentIndex = 0;

    // ===== Constructor =====
    constructor() ERC721("Verizon x Chibi Labs: Token of Love", "VZCL") {}

    uint public totalSupply = 0;

    // ===== Modifier =====
    function _onlySender() private view {
        require(msg.sender == tx.origin);
    }

    modifier onlySender {
        _onlySender();
        _;
    }

    // ===== Reserve mint =====
    function reserveMint(address to, uint256 amount) external onlySender onlyOwner {
        require((totalSupply + amount) <= collectionSize, "Over collection limit");
        for (uint i = 0; i < amount; i++) {
            totalSupply += 1;
            _mint(to, totalSupply);
        }        
    }

    function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    // ===== View =====
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }
}