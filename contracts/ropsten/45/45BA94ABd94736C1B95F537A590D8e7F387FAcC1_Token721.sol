// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Token721 is ERC721URIStorage {
    uint256 public current_tokenId = 0;
    string public baseURI;
    address public owner;

    constructor(
        string memory name_,
        string memory symbol_
        // string memory baseURI_
    ) ERC721(name_, symbol_) {
        // baseURI = baseURI_;
        owner = msg.sender;
    }

    function mint(address to, string memory tokenURI) public {
        current_tokenId++;
        _safeMint(to, current_tokenId);
        _setTokenURI(current_tokenId, tokenURI);
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }

    function setBaseURI(string memory baseURI_) external virtual {
        require(owner == msg.sender, "must be owner");
        baseURI = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
}