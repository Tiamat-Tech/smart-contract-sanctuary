// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract DLWC is IERC165, ERC721, IERC721Enumerable {
    string private constant _NAME = "Twoken 2";
    string private constant _SYMBOL = "TWO";
    string private constant _URI = "data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2036%2036%22%3E%3Cpath%20fill%3D%22%23ff0%22%20d%3D%22M0%200L18%2036L36%200H0%22%2F%3E%3C%2Fsvg%3E%0A";

    constructor() ERC721("", "") {
        _safeMint(msg.sender, 0, "");
        _safeMint(msg.sender, 1, "");
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return _URI;
    }

    function name() public pure override returns (string memory) {
        return _NAME;
    }

    function symbol() public pure override returns (string memory) {
        return _SYMBOL;
    }

    function totalSupply() public pure override returns (uint256) {
        return 2;
    }

    function tokenByIndex(uint256 index)
        public
        pure
        virtual
        override
        returns (uint256)
    {
        require(index < 2, "ERC721Enumerable: global index out of bounds");
        return index;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        override
        returns (uint256 tokenId)
    {
        require(
            index < balanceOf(owner),
            "ERC721Enumerable: owner index out of bounds"
        );
        return index == 0 && owner == ownerOf(0) ? 0 : 1;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}