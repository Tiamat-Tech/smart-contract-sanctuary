// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BadGifts is ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant WITHDRAWAL_ROLE = keccak256("WITHDRAWAL_ROLE");
    uint256 public mintPrice = 20000000000000000;
    uint256 public maxSupply = 6969;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Bad Gifts", "BG") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://badgifts.ciberchico.com";
    }

    function safeMint(address to, uint256 amount) public payable {
        uint256 supply = totalSupply();
        uint256 afterSupply = supply + amount;
        require(afterSupply <= maxSupply, "Max supply has been reached");
        require(msg.value*amount == mintPrice*amount, "Invalid price");

        for (uint256 i; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
        }
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}